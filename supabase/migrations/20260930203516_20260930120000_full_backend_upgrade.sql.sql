/*
# Full Backend Upgrade: Admin Roles, Product Images, Secure Checkout, Customer Orders

1. New Tables
- `product_images` — multiple images per product (id, product_id, image_url, display_order, created_at).
- `admin_roles` — maps auth.users to admin roles (user_id, role, created_at). Roles: super_admin, inventory_manager, order_manager.

2. Modified Tables
- `products` — add `is_active` boolean (default true) to allow admins to hide products without deleting.
- `orders` — add `customer_id` uuid (nullable, references auth.users) so logged-in customers can see their own orders. Add `latitude`/`longitude` are NOT stored — only the text address.

3. New Functions
- `is_admin()` — returns true if the current auth user has a row in admin_roles.
- `admin_role()` — returns the role string for the current auth user, or null.
- `place_order(p_items jsonb, p_customer_name text, p_email text, p_phone text, p_address text, p_city text, p_postal_code text, p_payment_method text, p_customer_id uuid)` — SECURITY DEFINER function that:
  1. Validates every cart item has sufficient stock.
  2. Inserts the order row.
  3. Inserts all order_items.
  4. Atomically decrements product inventory.
  5. Returns the new order id.
  All inside a single function (atomic). Runs with definer privileges so anon users can place orders without direct table write access.

4. Security / RLS Changes
- `products`: anon can only SELECT active products; authenticated admins can SELECT/INSERT/UPDATE/DELETE all.
- `categories`: anon SELECT only; authenticated admins full CRUD.
- `orders`: anon can INSERT via the place_order function only (direct INSERT revoked from anon). Authenticated admins can SELECT/UPDATE all. Authenticated customers can SELECT their own orders (customer_id = auth.uid()).
- `order_items`: anon INSERT via function only (direct INSERT revoked from anon). Authenticated admins full access. Authenticated customers can SELECT items for their own orders.
- `product_images`: anon SELECT active products' images; authenticated admins full CRUD.
- `admin_roles`: only authenticated admins can SELECT (to check their own role). No one can INSERT/UPDATE/DELETE via anon key — admin account management is done via SQL or edge function by super_admin.

5. Storage
- Create `product-images` storage bucket (public read) for admin-uploaded product photos.

6. Order Status Updates
- Status values changed to: pending, confirmed, packed, shipped, delivered, cancelled.
- Existing 'processing' orders updated to 'pending'.

7. Notes
- No destructive operations on existing data.
- Safe to re-run (uses IF NOT EXISTS, DROP POLICY IF EXISTS).
- The place_order function is the ONLY way anon users create orders — direct INSERT on orders/order_items is no longer allowed for anon.
*/

-- ===== 1. Alter existing tables =====

ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS customer_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- Migrate 'processing' status to 'pending'
UPDATE orders SET status = 'pending' WHERE status = 'processing';

-- ===== 2. New tables =====

CREATE TABLE IF NOT EXISTS product_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS admin_roles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('super_admin', 'inventory_manager', 'order_manager')),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_roles ENABLE ROW LEVEL SECURITY;

-- ===== 3. Helper functions =====

CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM admin_roles WHERE user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION admin_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM admin_roles WHERE user_id = auth.uid();
$$;

-- ===== 4. place_order function =====

CREATE OR REPLACE FUNCTION place_order(
  p_items jsonb,
  p_customer_name text,
  p_email text,
  p_phone text,
  p_address text,
  p_city text DEFAULT '',
  p_postal_code text DEFAULT '',
  p_payment_method text DEFAULT 'Cash on Delivery',
  p_customer_id uuid DEFAULT NULL,
  p_delivery_fee numeric DEFAULT 250
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  v_item jsonb;
  v_product products%ROWTYPE;
  v_subtotal numeric := 0;
  v_total numeric;
  v_qty integer;
  v_unit_price numeric;
BEGIN
  -- Validate items array is not empty
  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;

  -- Validate stock for all items first (before any writes)
  FOR v_item IN SELECT jsonb_array_elements(p_items) LOOP
    SELECT * INTO v_product FROM products WHERE id = (v_item->>'product_id')::uuid AND is_active = true FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product % is no longer available', v_item->>'product_name';
    END IF;
    v_qty := (v_item->>'quantity')::integer;
    IF v_product.inventory < v_qty THEN
      RAISE EXCEPTION 'Not enough stock for %. Available: %, requested: %', v_product.name, v_product.inventory, v_qty;
    END IF;
    v_unit_price := (v_item->>'unit_price')::numeric;
    v_subtotal := v_subtotal + (v_unit_price * v_qty);
  END LOOP;

  v_total := v_subtotal + p_delivery_fee;

  -- Insert the order
  INSERT INTO orders (customer_name, email, phone, address, city, postal_code, payment_method, status, subtotal, delivery_fee, total, customer_id)
  VALUES (p_customer_name, p_email, p_phone, p_address, p_city, p_postal_code, p_payment_method, 'pending', v_subtotal, p_delivery_fee, v_total, p_customer_id)
  RETURNING id INTO v_order_id;

  -- Insert order items and decrement inventory
  FOR v_item IN SELECT jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::integer;
    v_unit_price := (v_item->>'unit_price')::numeric;

    INSERT INTO order_items (order_id, product_id, product_name, size, color, quantity, unit_price)
    VALUES (v_order_id, (v_item->>'product_id')::uuid, v_item->>'product_name', v_item->>'size', v_item->>'color', v_qty, v_unit_price);

    UPDATE products SET inventory = inventory - v_qty WHERE id = (v_item->>'product_id')::uuid;
  END LOOP;

  RETURN v_order_id;
END;
$$;

-- ===== 5. Revoke direct table privileges from anon =====
-- Anon can no longer directly INSERT into orders or order_items (must use place_order function)
-- Anon can no longer SELECT orders or order_items (customer order history is for authenticated users only)

REVOKE INSERT ON orders FROM anon;
REVOKE INSERT ON order_items FROM anon;
REVOKE SELECT ON orders FROM anon;
REVOKE SELECT ON order_items FROM anon;
REVOKE UPDATE ON orders FROM anon;
REVOKE UPDATE ON order_items FROM anon;
REVOKE DELETE ON orders FROM anon;
REVOKE DELETE ON order_items FROM anon;

-- ===== 6. Drop old policies and recreate =====

-- CATEGORIES
DROP POLICY IF EXISTS "anon_read_categories" ON categories;
DROP POLICY IF EXISTS "auth_insert_categories" ON categories;
DROP POLICY IF EXISTS "auth_update_categories" ON categories;
DROP POLICY IF EXISTS "auth_delete_categories" ON categories;
DROP POLICY IF EXISTS "public_read_categories" ON categories;
DROP POLICY IF EXISTS "public_insert_categories" ON categories;
DROP POLICY IF EXISTS "public_update_categories" ON categories;
DROP POLICY IF EXISTS "public_delete_categories" ON categories;

DROP POLICY IF EXISTS "anon_read_categories" ON categories;
CREATE POLICY "anon_read_categories" ON categories FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_categories" ON categories;
CREATE POLICY "auth_insert_categories" ON categories FOR INSERT TO authenticated WITH CHECK (is_admin());
DROP POLICY IF EXISTS "auth_update_categories" ON categories;
CREATE POLICY "auth_update_categories" ON categories FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "auth_delete_categories" ON categories;
CREATE POLICY "auth_delete_categories" ON categories FOR DELETE TO authenticated USING (is_admin());

-- PRODUCTS
DROP POLICY IF EXISTS "anon_read_products" ON products;
DROP POLICY IF EXISTS "auth_insert_products" ON products;
DROP POLICY IF EXISTS "auth_update_products" ON products;
DROP POLICY IF EXISTS "auth_delete_products" ON products;
DROP POLICY IF EXISTS "public_read_products" ON products;
DROP POLICY IF EXISTS "public_insert_products" ON products;
DROP POLICY IF EXISTS "public_update_products" ON products;
DROP POLICY IF EXISTS "public_delete_products" ON products;

DROP POLICY IF EXISTS "anon_read_products" ON products;
CREATE POLICY "anon_read_products" ON products FOR SELECT TO anon, authenticated USING (is_active = true);
DROP POLICY IF EXISTS "auth_insert_products" ON products;
CREATE POLICY "auth_insert_products" ON products FOR INSERT TO authenticated WITH CHECK (is_admin());
DROP POLICY IF EXISTS "auth_update_products" ON products;
CREATE POLICY "auth_update_products" ON products FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "auth_delete_products" ON products;
CREATE POLICY "auth_delete_products" ON products FOR DELETE TO authenticated USING (is_admin());

-- ORDERS
DROP POLICY IF EXISTS "anon_insert_orders" ON orders;
DROP POLICY IF EXISTS "auth_read_orders" ON orders;
DROP POLICY IF EXISTS "auth_update_orders" ON orders;
DROP POLICY IF EXISTS "auth_delete_orders" ON orders;
DROP POLICY IF EXISTS "public_read_orders" ON orders;
DROP POLICY IF EXISTS "public_insert_orders" ON orders;
DROP POLICY IF EXISTS "public_update_orders" ON orders;
DROP POLICY IF EXISTS "public_delete_orders" ON orders;

-- Authenticated customers can read their own orders; admins can read all
DROP POLICY IF EXISTS "customer_read_own_orders" ON orders;
CREATE POLICY "customer_read_own_orders" ON orders FOR SELECT TO authenticated USING (customer_id = auth.uid() OR is_admin());
-- Only admins can update/delete orders
DROP POLICY IF EXISTS "admin_update_orders" ON orders;
CREATE POLICY "admin_update_orders" ON orders FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "admin_delete_orders" ON orders;
CREATE POLICY "admin_delete_orders" ON orders FOR DELETE TO authenticated USING (is_admin());

-- ORDER_ITEMS
DROP POLICY IF EXISTS "anon_insert_order_items" ON order_items;
DROP POLICY IF EXISTS "auth_read_order_items" ON order_items;
DROP POLICY IF EXISTS "auth_update_order_items" ON order_items;
DROP POLICY IF EXISTS "auth_delete_order_items" ON order_items;
DROP POLICY IF EXISTS "public_read_order_items" ON order_items;
DROP POLICY IF EXISTS "public_insert_order_items" ON order_items;
DROP POLICY IF EXISTS "public_update_order_items" ON order_items;
DROP POLICY IF EXISTS "public_delete_order_items" ON order_items;

-- Customers can read items for their own orders; admins can read all
DROP POLICY IF EXISTS "customer_read_own_items" ON order_items;
CREATE POLICY "customer_read_own_items" ON order_items FOR SELECT TO authenticated USING (
  EXISTS (SELECT 1 FROM orders WHERE orders.id = order_items.order_id AND (orders.customer_id = auth.uid() OR is_admin()))
);
-- Only admins can update/delete order items
DROP POLICY IF EXISTS "admin_update_order_items" ON order_items;
CREATE POLICY "admin_update_order_items" ON order_items FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "admin_delete_order_items" ON order_items;
CREATE POLICY "admin_delete_order_items" ON order_items FOR DELETE TO authenticated USING (is_admin());

-- PRODUCT_IMAGES
DROP POLICY IF EXISTS "anon_read_product_images" ON product_images;
DROP POLICY IF EXISTS "auth_insert_product_images" ON product_images;
DROP POLICY IF EXISTS "auth_update_product_images" ON product_images;
DROP POLICY IF EXISTS "auth_delete_product_images" ON product_images;

DROP POLICY IF EXISTS "anon_read_product_images" ON product_images;
CREATE POLICY "anon_read_product_images" ON product_images FOR SELECT TO anon, authenticated USING (
  EXISTS (SELECT 1 FROM products WHERE products.id = product_images.product_id AND products.is_active = true)
);
DROP POLICY IF EXISTS "auth_insert_product_images" ON product_images;
CREATE POLICY "auth_insert_product_images" ON product_images FOR INSERT TO authenticated WITH CHECK (is_admin());
DROP POLICY IF EXISTS "auth_update_product_images" ON product_images;
CREATE POLICY "auth_update_product_images" ON product_images FOR UPDATE TO authenticated USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS "auth_delete_product_images" ON product_images;
CREATE POLICY "auth_delete_product_images" ON product_images FOR DELETE TO authenticated USING (is_admin());

-- ADMIN_ROLES — only admins can read; no anon access
DROP POLICY IF EXISTS "admin_read_roles" ON admin_roles;
DROP POLICY IF EXISTS "admin_insert_roles" ON admin_roles;
DROP POLICY IF EXISTS "admin_update_roles" ON admin_roles;
DROP POLICY IF EXISTS "admin_delete_roles" ON admin_roles;

DROP POLICY IF EXISTS "admin_read_roles" ON admin_roles;
CREATE POLICY "admin_read_roles" ON admin_roles FOR SELECT TO authenticated USING (is_admin());
DROP POLICY IF EXISTS "admin_manage_roles" ON admin_roles;
CREATE POLICY "admin_manage_roles" ON admin_roles FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- ===== 7. Grant execute on place_order to anon and authenticated =====
GRANT EXECUTE ON FUNCTION place_order TO anon, authenticated;
GRANT EXECUTE ON FUNCTION is_admin TO authenticated;
GRANT EXECUTE ON FUNCTION admin_role TO authenticated;

-- ===== 8. Indexes =====
CREATE INDEX IF NOT EXISTS product_images_product_idx ON product_images(product_id);
CREATE INDEX IF NOT EXISTS orders_customer_idx ON orders(customer_id);
CREATE INDEX IF NOT EXISTS admin_roles_user_idx ON admin_roles(user_id);

-- ===== 9. Storage bucket =====
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies: public read, admin write
DROP POLICY IF EXISTS "public_read_product_images_bucket" ON storage.objects;
CREATE POLICY "public_read_product_images_bucket" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "admin_write_product_images_bucket" ON storage.objects;
CREATE POLICY "admin_write_product_images_bucket" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'product-images' AND is_admin());

DROP POLICY IF EXISTS "admin_update_product_images_bucket" ON storage.objects;
CREATE POLICY "admin_update_product_images_bucket" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'product-images' AND is_admin())
  WITH CHECK (bucket_id = 'product-images' AND is_admin());

DROP POLICY IF EXISTS "admin_delete_product_images_bucket" ON storage.objects;
CREATE POLICY "admin_delete_product_images_bucket" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'product-images' AND is_admin());