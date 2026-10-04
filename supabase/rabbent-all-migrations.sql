-- ===== migrations/20260923194016_create_rabbent_store.sql =====
/*
# Create Rabbent storefront data model

1. New Tables
- `categories` — public product groups with display ordering.
- `products` — public catalog items with name, description, price, image, category, sizes, colors, inventory, and featured status.
- `orders` — customer checkout submissions with contact, delivery address, payment method, status, and totals.
- `order_items` — immutable line items linked to an order and product.

2. Security
- Row level security is enabled on every table.
- This is a single-tenant storefront without sign-in, so anonymous and authenticated visitors can browse the catalog and submit checkout orders.
- Order records are intentionally shared with the storefront service role pattern and limited to the public checkout fields needed for this demonstration.

3. Notes
- Product catalog is seeded with Rabbent's launch collection.
- No destructive operations are used; this migration is safe to re-run.
*/

CREATE TABLE IF NOT EXISTS categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE,
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid REFERENCES categories(id) ON DELETE SET NULL,
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text NOT NULL DEFAULT '',
  price numeric(10,2) NOT NULL CHECK (price >= 0),
  compare_at_price numeric(10,2),
  image_url text NOT NULL,
  sizes text[] NOT NULL DEFAULT ARRAY['S','M','L','XL'],
  colors text[] NOT NULL DEFAULT ARRAY['Black'],
  inventory integer NOT NULL DEFAULT 0 CHECK (inventory >= 0),
  featured boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name text NOT NULL,
  email text NOT NULL,
  phone text NOT NULL DEFAULT '',
  address text NOT NULL,
  city text NOT NULL DEFAULT '',
  postal_code text NOT NULL DEFAULT '',
  payment_method text NOT NULL DEFAULT 'Cash on Delivery',
  status text NOT NULL DEFAULT 'processing',
  subtotal numeric(10,2) NOT NULL DEFAULT 0,
  delivery_fee numeric(10,2) NOT NULL DEFAULT 250,
  total numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES products(id) ON DELETE SET NULL,
  product_name text NOT NULL,
  size text NOT NULL,
  color text NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price numeric(10,2) NOT NULL CHECK (unit_price >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_read_categories" ON categories;
CREATE POLICY "public_read_categories" ON categories FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "public_insert_categories" ON categories;
CREATE POLICY "public_insert_categories" ON categories FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "public_update_categories" ON categories;
CREATE POLICY "public_update_categories" ON categories FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "public_delete_categories" ON categories;
CREATE POLICY "public_delete_categories" ON categories FOR DELETE TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read_products" ON products;
CREATE POLICY "public_read_products" ON products FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "public_insert_products" ON products;
CREATE POLICY "public_insert_products" ON products FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "public_update_products" ON products;
CREATE POLICY "public_update_products" ON products FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "public_delete_products" ON products;
CREATE POLICY "public_delete_products" ON products FOR DELETE TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read_orders" ON orders;
CREATE POLICY "public_read_orders" ON orders FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "public_insert_orders" ON orders;
CREATE POLICY "public_insert_orders" ON orders FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "public_update_orders" ON orders;
CREATE POLICY "public_update_orders" ON orders FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "public_delete_orders" ON orders;
CREATE POLICY "public_delete_orders" ON orders FOR DELETE TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "public_read_order_items" ON order_items;
CREATE POLICY "public_read_order_items" ON order_items FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "public_insert_order_items" ON order_items;
CREATE POLICY "public_insert_order_items" ON order_items FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "public_update_order_items" ON order_items;
CREATE POLICY "public_update_order_items" ON order_items FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "public_delete_order_items" ON order_items;
CREATE POLICY "public_delete_order_items" ON order_items FOR DELETE TO anon, authenticated USING (true);

INSERT INTO categories (name, slug, display_order) VALUES
  ('New Arrivals', 'new-arrivals', 1),
  ('Women', 'women', 2),
  ('Men', 'men', 3),
  ('Essentials', 'essentials', 4)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO products (category_id, name, slug, description, price, compare_at_price, image_url, sizes, colors, inventory, featured)
SELECT c.id, p.name, p.slug, p.description, p.price, p.compare_at_price, p.image_url, p.sizes, p.colors, p.inventory, p.featured
FROM (VALUES
  ('new-arrivals','Classic Oversized Shirt','classic-oversized-shirt','A relaxed cotton shirt with an easy, everyday drape. Cut for movement and made to become your most-worn layer.',4990.00,NULL,'https://images.pexels.com/photos/8651009/pexels-photo-8651009.jpeg?auto=compress&cs=tinysrgb&h=650&w=940',ARRAY['S','M','L','XL'],ARRAY['Black','White'],42,true),
  ('men','Urban Utility Jacket','urban-utility-jacket','A structured utility jacket with considered pockets and a soft brushed finish.',7490.00,8490.00,'https://images.pexels.com/photos/26936522/pexels-photo-26936522.jpeg?auto=compress&cs=tinysrgb&h=650&w=940',ARRAY['S','M','L','XL'],ARRAY['Stone','Black'],18,true),
  ('essentials','Essential Hoodie','essential-hoodie','Heavyweight brushed fleece, dropped shoulders, and a clean tonal finish.',5490.00,NULL,'https://images.pexels.com/photos/6616673/pexels-photo-6616673.jpeg?auto=compress&cs=tinysrgb&h=650&w=940',ARRAY['S','M','L','XL'],ARRAY['Grey','Black'],35,true),
  ('women','Relaxed Trousers','relaxed-trousers','High-rise trousers with a generous straight leg and a soft, tailored handfeel.',4290.00,NULL,'https://images.pexels.com/photos/8796462/pexels-photo-8796462.jpeg?auto=compress&cs=tinysrgb&h=650&w=940',ARRAY['S','M','L'],ARRAY['Black','Moss'],24,false),
  ('women','Studio Blazer','studio-blazer','A softly tailored blazer designed to move between work, dinner, and everything after.',8990.00,NULL,'https://images.pexels.com/photos/33401553/pexels-photo-33401553.jpeg?auto=compress&cs=tinysrgb&h=650&w=940',ARRAY['S','M','L','XL'],ARRAY['Check','Oat'],15,false),
  ('essentials','Everyday Rib Top','everyday-rib-top','A close-fitting ribbed top with a clean neckline and versatile layering weight.',2490.00,NULL,'https://images.pexels.com/photos/34299100/pexels-photo-34299100.jpeg?auto=compress&cs=tinysrgb&h=650&w=940',ARRAY['XS','S','M','L'],ARRAY['White','Black'],29,false)
) AS p(category_slug, name, slug, description, price, compare_at_price, image_url, sizes, colors, inventory, featured)
JOIN categories c ON c.slug = p.category_slug
ON CONFLICT (slug) DO NOTHING;

CREATE INDEX IF NOT EXISTS products_category_idx ON products(category_id);
CREATE INDEX IF NOT EXISTS products_featured_idx ON products(featured);
CREATE INDEX IF NOT EXISTS orders_created_at_idx ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS order_items_order_idx ON order_items(order_id);
-- ===== migrations/20260924103336_tighten_rls_for_admin_auth.sql =====
/*
# Tighten RLS: protect admin operations, keep storefront public

1. Purpose
- The storefront (browsing products, placing orders) must remain public for anonymous customers.
- The admin dashboard (viewing all orders, managing products, updating order status) must be restricted to authenticated admin users only.
- Anonymous users can no longer read orders or order_items, and can no longer modify products or categories.

2. Policy changes
- categories: anon SELECT only; authenticated full CRUD.
- products: anon SELECT only; authenticated full CRUD.
- orders: anon INSERT only (checkout); authenticated full CRUD.
- order_items: anon INSERT only (checkout); authenticated full CRUD.

3. Notes
- No data is lost; only policy permissions change.
- Safe to re-run (policies dropped before recreate).
*/

DROP POLICY IF EXISTS "public_read_categories" ON categories;
DROP POLICY IF EXISTS "public_insert_categories" ON categories;
DROP POLICY IF EXISTS "public_update_categories" ON categories;
DROP POLICY IF EXISTS "public_delete_categories" ON categories;

DROP POLICY IF EXISTS "anon_read_categories" ON categories;
CREATE POLICY "anon_read_categories" ON categories FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_categories" ON categories;
CREATE POLICY "auth_insert_categories" ON categories FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_categories" ON categories;
CREATE POLICY "auth_update_categories" ON categories FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "auth_delete_categories" ON categories;
CREATE POLICY "auth_delete_categories" ON categories FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "public_read_products" ON products;
DROP POLICY IF EXISTS "public_insert_products" ON products;
DROP POLICY IF EXISTS "public_update_products" ON products;
DROP POLICY IF EXISTS "public_delete_products" ON products;

DROP POLICY IF EXISTS "anon_read_products" ON products;
CREATE POLICY "anon_read_products" ON products FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "auth_insert_products" ON products;
CREATE POLICY "auth_insert_products" ON products FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_update_products" ON products;
CREATE POLICY "auth_update_products" ON products FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "auth_delete_products" ON products;
CREATE POLICY "auth_delete_products" ON products FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "public_read_orders" ON orders;
DROP POLICY IF EXISTS "public_insert_orders" ON orders;
DROP POLICY IF EXISTS "public_update_orders" ON orders;
DROP POLICY IF EXISTS "public_delete_orders" ON orders;

DROP POLICY IF EXISTS "anon_insert_orders" ON orders;
CREATE POLICY "anon_insert_orders" ON orders FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_read_orders" ON orders;
CREATE POLICY "auth_read_orders" ON orders FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_update_orders" ON orders;
CREATE POLICY "auth_update_orders" ON orders FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "auth_delete_orders" ON orders;
CREATE POLICY "auth_delete_orders" ON orders FOR DELETE TO authenticated USING (true);

DROP POLICY IF EXISTS "public_read_order_items" ON order_items;
DROP POLICY IF EXISTS "public_insert_order_items" ON order_items;
DROP POLICY IF EXISTS "public_update_order_items" ON order_items;
DROP POLICY IF EXISTS "public_delete_order_items" ON order_items;

DROP POLICY IF EXISTS "anon_insert_order_items" ON order_items;
CREATE POLICY "anon_insert_order_items" ON order_items FOR INSERT TO anon, authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "auth_read_order_items" ON order_items;
CREATE POLICY "auth_read_order_items" ON order_items FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "auth_update_order_items" ON order_items;
CREATE POLICY "auth_update_order_items" ON order_items FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "auth_delete_order_items" ON order_items;
CREATE POLICY "auth_delete_order_items" ON order_items FOR DELETE TO authenticated USING (true);
-- ===== migrations/20260924111053_add_souvenirs_and_caps.sql =====
/*
# Add Souvenirs and Caps categories with products

1. New Categories
- `souvenirs` (display_order 5) — branded merchandise and keepsakes.
- `caps` (display_order 6) — headwear.

2. New Products (6 items)
- Classic Logo Cap, Sport Six-Panel Cap, Rabbent Canvas Tote, Studio Ceramic Mug, Rabbent Logo Keychain, Art Print Postcard Set.

3. Notes
- Uses ON CONFLICT DO NOTHING for idempotency.
- Explicit type casts on numeric columns.
*/

INSERT INTO categories (name, slug, display_order) VALUES
  ('Souvenirs', 'souvenirs', 5),
  ('Caps', 'caps', 6)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO products (category_id, name, slug, description, price, compare_at_price, image_url, sizes, colors, inventory, featured)
SELECT c.id, p.name, p.slug, p.description, p.price::numeric(10,2), p.compare_at_price::numeric(10,2), p.image_url, p.sizes::text[], p.colors::text[], p.inventory::integer, p.featured::boolean
FROM (VALUES
  ('caps','Classic Logo Cap','classic-logo-cap','A structured cotton cap with an embroidered Rabbent mark and a clean curved brim.',2490.00,NULL,'https://images.pexels.com/photos/13876038/pexels-photo-13876038.jpeg?auto=compress&cs=tinysrgb&h=650&w=940','{One Size}','{Black,Olive}',30,true),
  ('caps','Sport Six-Panel Cap','sport-six-panel-cap','A breathable six-panel cap with a pre-curved brim and adjustable strap.',2290.00,NULL,'https://images.pexels.com/photos/13447017/pexels-photo-13447017.jpeg?auto=compress&cs=tinysrgb&h=650&w=940','{One Size}','{Beige,White}',28,false),
  ('souvenirs','Rabbent Canvas Tote','rabbent-canvas-tote','A heavyweight natural canvas tote with a tonal Rabbent print. Roomy enough for everyday carry.',1990.00,NULL,'https://images.pexels.com/photos/33263825/pexels-photo-33263825.jpeg?auto=compress&cs=tinysrgb&h=650&w=940','{One Size}','{Natural}',45,true),
  ('souvenirs','Studio Ceramic Mug','studio-ceramic-mug','A matte-glazed ceramic mug in a comfortable 350ml size. Made for slow mornings.',1790.00,NULL,'https://images.pexels.com/photos/21624841/pexels-photo-21624841.jpeg?auto=compress&cs=tinysrgb&h=650&w=940','{350ml}','{Ink,Oat}',38,false),
  ('souvenirs','Rabbent Logo Keychain','rabbent-logo-keychain','A minimalist brushed-metal keychain with a subtle engraved Rabbent mark.',990.00,NULL,'https://images.pexels.com/photos/13062786/pexels-photo-13062786.jpeg?auto=compress&cs=tinysrgb&h=650&w=940','{One Size}','{Silver}',60,false),
  ('souvenirs','Art Print Postcard Set','art-print-postcard-set','A set of three art-print postcards featuring Rabbent seasonal photography. Printed on heavy stock.',1290.00,NULL,'https://images.pexels.com/photos/39422921/pexels-photo-39422921.jpeg?auto=compress&cs=tinysrgb&h=650&w=940','{Set of 3}','{Multi}',50,false)
) AS p(category_slug, name, slug, description, price, compare_at_price, image_url, sizes, colors, inventory, featured)
JOIN categories c ON c.slug = p.category_slug
ON CONFLICT (slug) DO NOTHING;
-- ===== migrations/20260930203516_20260930120000_full_backend_upgrade.sql.sql =====
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

-- ===== migrations/20261002000000_proposal_modules.sql =====
-- Adds the remaining proposal modules: coupons, banners, reviews, wishlist, addresses (+map coordinates), variants.
ALTER TABLE orders ADD COLUMN IF NOT EXISTS latitude double precision;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS longitude double precision;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount numeric NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS coupon_code text;

CREATE TABLE IF NOT EXISTS coupons (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE NOT NULL, percent_off integer NOT NULL CHECK (percent_off BETWEEN 1 AND 90), active boolean NOT NULL DEFAULT true, expires_at timestamptz, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS banners (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, subtitle text DEFAULT '', active boolean NOT NULL DEFAULT true, display_order integer NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS reviews (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE, user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, author text NOT NULL DEFAULT 'Customer', rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5), body text NOT NULL DEFAULT '', created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS wishlist_items (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE, UNIQUE (user_id, product_id));
CREATE TABLE IF NOT EXISTS addresses (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, label text NOT NULL DEFAULT 'Home', address text NOT NULL, city text DEFAULT '', postal_code text DEFAULT '', latitude double precision, longitude double precision, created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS product_variants (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE, size text NOT NULL, color text NOT NULL, stock integer NOT NULL DEFAULT 0, price_override numeric, created_at timestamptz NOT NULL DEFAULT now());

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['coupons','banners','reviews','wishlist_items','addresses','product_variants'] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "admin_all_%1$s" ON %1$I', t);
    EXECUTE format('CREATE POLICY "admin_all_%1$s" ON %1$I FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin())', t);
  END LOOP;
END $$;

DROP POLICY IF EXISTS "read_banners" ON banners;
CREATE POLICY "read_banners" ON banners FOR SELECT TO anon, authenticated USING (active);
DROP POLICY IF EXISTS "read_variants" ON product_variants;
CREATE POLICY "read_variants" ON product_variants FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "read_reviews" ON reviews;
CREATE POLICY "read_reviews" ON reviews FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "own_reviews" ON reviews;
CREATE POLICY "own_reviews" ON reviews FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "own_wishlist" ON wishlist_items;
CREATE POLICY "own_wishlist" ON wishlist_items FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "own_addresses" ON addresses;
CREATE POLICY "own_addresses" ON addresses FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Returns percent off for a valid coupon (0 if invalid). Coupons are not readable directly by shoppers.
CREATE OR REPLACE FUNCTION check_coupon(p_code text) RETURNS integer LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((SELECT percent_off FROM coupons WHERE upper(code) = upper(p_code) AND active AND (expires_at IS NULL OR expires_at > now())), 0);
$$;
GRANT EXECUTE ON FUNCTION check_coupon TO anon, authenticated;

-- Extra order details (coupon + map pin) applied right after place_order; the order id is an unguessable uuid.
CREATE OR REPLACE FUNCTION finalize_order(p_order_id uuid, p_coupon text, p_lat double precision, p_lng double precision) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE pct integer := check_coupon(p_coupon); o orders%ROWTYPE;
BEGIN
  SELECT * INTO o FROM orders WHERE id = p_order_id AND created_at > now() - interval '10 minutes' AND discount = 0;
  IF NOT FOUND THEN RETURN; END IF;
  UPDATE orders SET latitude = p_lat, longitude = p_lng, coupon_code = CASE WHEN pct > 0 THEN upper(p_coupon) END,
    discount = round(o.subtotal * pct / 100.0), total = o.total - round(o.subtotal * pct / 100.0) WHERE id = p_order_id;
END $$;
GRANT EXECUTE ON FUNCTION finalize_order TO anon, authenticated;

INSERT INTO banners (title, subtitle) SELECT 'New season, new Rabbent', 'Free delivery over Rs. 8,000' WHERE NOT EXISTS (SELECT 1 FROM banners);
INSERT INTO coupons (code, percent_off) VALUES ('WELCOME10', 10) ON CONFLICT DO NOTHING;

-- Prices are now decided by the database (product price, or the size-specific variant price), never by the browser.
CREATE OR REPLACE FUNCTION place_order(p_items jsonb, p_customer_name text, p_email text, p_phone text, p_address text, p_city text DEFAULT '', p_postal_code text DEFAULT '', p_payment_method text DEFAULT 'Cash on Delivery', p_customer_id uuid DEFAULT NULL, p_delivery_fee numeric DEFAULT 250)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_order_id uuid; v_item jsonb; v_product products%ROWTYPE; v_subtotal numeric := 0; v_qty integer; v_price numeric;
BEGIN
  IF jsonb_array_length(p_items) = 0 THEN RAISE EXCEPTION 'Cart is empty'; END IF;
  FOR v_item IN SELECT jsonb_array_elements(p_items) LOOP
    SELECT * INTO v_product FROM products WHERE id = (v_item->>'product_id')::uuid AND is_active = true FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Product % is no longer available', v_item->>'product_name'; END IF;
    v_qty := (v_item->>'quantity')::integer;
    IF v_qty < 1 THEN RAISE EXCEPTION 'Invalid quantity'; END IF;
    IF v_product.inventory < v_qty THEN RAISE EXCEPTION 'Not enough stock for %. Available: %, requested: %', v_product.name, v_product.inventory, v_qty; END IF;
    SELECT price_override INTO v_price FROM product_variants WHERE product_id = v_product.id AND lower(size) = lower(v_item->>'size') AND price_override IS NOT NULL ORDER BY (lower(color) = lower(coalesce(v_item->>'color',''))) DESC LIMIT 1;
    v_subtotal := v_subtotal + coalesce(v_price, v_product.price) * v_qty;
  END LOOP;
  INSERT INTO orders (customer_name, email, phone, address, city, postal_code, payment_method, status, subtotal, delivery_fee, total, customer_id)
  VALUES (p_customer_name, p_email, p_phone, p_address, p_city, p_postal_code, p_payment_method, 'pending', v_subtotal, p_delivery_fee, v_subtotal + p_delivery_fee, p_customer_id) RETURNING id INTO v_order_id;
  FOR v_item IN SELECT jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::integer;
    SELECT * INTO v_product FROM products WHERE id = (v_item->>'product_id')::uuid;
    SELECT price_override INTO v_price FROM product_variants WHERE product_id = v_product.id AND lower(size) = lower(v_item->>'size') AND price_override IS NOT NULL ORDER BY (lower(color) = lower(coalesce(v_item->>'color',''))) DESC LIMIT 1;
    INSERT INTO order_items (order_id, product_id, product_name, size, color, quantity, unit_price)
    VALUES (v_order_id, v_product.id, v_product.name, v_item->>'size', v_item->>'color', v_qty, coalesce(v_price, v_product.price));
    UPDATE products SET inventory = inventory - v_qty WHERE id = v_product.id;
  END LOOP;
  RETURN v_order_id;
END $$;
GRANT EXECUTE ON FUNCTION place_order(jsonb, text, text, text, text, text, text, text, uuid, numeric) TO anon, authenticated;

-- ===== migrations/20261003000000_delivery_and_payments.sql =====
-- Delivery by weight and zone (courier rate card, minimum Rs. 350), COD surcharge folded into delivery,
-- Easypaisa (manual) payment reference, and a server-side checkout quote.
-- Safe to run more than once.

ALTER TABLE products ADD COLUMN IF NOT EXISTS weight_kg numeric(6,2) NOT NULL DEFAULT 0.5;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS weight_kg numeric(6,2) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_zone text;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cod_fee numeric(10,2) NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_reference text;

-- Courier rates per zone, all taxes included (edit in Admin > Rates if the courier changes them).
CREATE TABLE IF NOT EXISTS delivery_rates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone text UNIQUE NOT NULL,
  label text NOT NULL DEFAULT '',
  rate_half numeric NOT NULL,   -- up to 0.5 kg
  rate_one numeric NOT NULL,    -- up to 1 kg
  rate_extra numeric NOT NULL,  -- each additional kg (or part of a kg)
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Lowest courier charge for any parcel, before the cash-on-delivery charge (editable in Admin > Delivery rates).
ALTER TABLE delivery_rates ADD COLUMN IF NOT EXISTS min_fee numeric NOT NULL DEFAULT 350;

INSERT INTO delivery_rates (zone, label, rate_half, rate_one, rate_extra) VALUES
  ('city',       'Within city',              153, 169, 169),
  ('region',     'Same region',              177, 196, 196),
  ('region_ext', 'Same region (extended)',   276, 302, 302),
  ('diff',       'Different region',         196, 241, 241),
  ('diff_ext',   'Different region (extended)', 302, 337, 337)
ON CONFLICT (zone) DO NOTHING;

-- Which zone each city belongs to. Ships from Sargodha, so Sargodha is "city".
-- Cities not listed here are charged as "diff" (different region).
CREATE TABLE IF NOT EXISTS delivery_cities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  city text NOT NULL,
  zone text NOT NULL REFERENCES delivery_rates(zone) ON UPDATE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS delivery_cities_city_key ON delivery_cities (lower(trim(city)));

INSERT INTO delivery_cities (city, zone) VALUES
  ('Sargodha', 'city'),
  ('Lahore', 'region'), ('Faisalabad', 'region'), ('Rawalpindi', 'region'), ('Islamabad', 'region'),
  ('Multan', 'region'), ('Gujranwala', 'region'), ('Gujrat', 'region'), ('Sialkot', 'region'),
  ('Bahawalpur', 'region'), ('Sahiwal', 'region'), ('Jhang', 'region'), ('Sheikhupura', 'region'),
  ('Kasur', 'region'), ('Okara', 'region'), ('Rahim Yar Khan', 'region'), ('Dera Ghazi Khan', 'region'),
  ('Mianwali', 'region'), ('Khushab', 'region'), ('Bhakkar', 'region'), ('Chiniot', 'region'),
  ('Jhelum', 'region'), ('Wah Cantt', 'region'), ('Attock', 'region'), ('Mandi Bahauddin', 'region'),
  ('Hafizabad', 'region'), ('Narowal', 'region'), ('Toba Tek Singh', 'region'), ('Vehari', 'region'),
  ('Khanewal', 'region'), ('Lodhran', 'region'), ('Muzaffargarh', 'region'), ('Layyah', 'region'),
  ('Pakpattan', 'region'), ('Bahawalnagar', 'region'), ('Chakwal', 'region'),
  ('Karachi', 'diff'), ('Hyderabad', 'diff'), ('Sukkur', 'diff'), ('Larkana', 'diff'),
  ('Nawabshah', 'diff'), ('Peshawar', 'diff'), ('Mardan', 'diff'), ('Abbottabad', 'diff'),
  ('Kohat', 'diff'), ('Swat', 'diff'), ('Quetta', 'diff'),
  ('Gwadar', 'diff_ext'), ('Turbat', 'diff_ext'), ('Gilgit', 'diff_ext'), ('Skardu', 'diff_ext'),
  ('Chitral', 'diff_ext'), ('Muzaffarabad', 'diff_ext'), ('Mirpur', 'diff_ext')
ON CONFLICT DO NOTHING;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['delivery_rates','delivery_cities'] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "admin_all_%1$s" ON %1$I', t);
    EXECUTE format('CREATE POLICY "admin_all_%1$s" ON %1$I FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin())', t);
    EXECUTE format('DROP POLICY IF EXISTS "read_%1$s" ON %1$I', t);
    EXECUTE format('CREATE POLICY "read_%1$s" ON %1$I FOR SELECT TO anon, authenticated USING (true)', t);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION zone_for_city(p_city text) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((SELECT zone FROM delivery_cities WHERE lower(trim(city)) = lower(trim(coalesce(p_city, ''))) LIMIT 1), 'diff');
$$;

-- Courier charge for a zone and total weight: first 0.5 kg, up to 1 kg, then each extra kg started.
CREATE OR REPLACE FUNCTION delivery_base_fee(p_zone text, p_weight numeric) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r delivery_rates%ROWTYPE;
BEGIN
  SELECT * INTO r FROM delivery_rates WHERE zone = p_zone;
  IF NOT FOUND THEN SELECT * INTO r FROM delivery_rates WHERE zone = 'diff'; END IF;
  IF NOT FOUND THEN RAISE EXCEPTION 'Delivery rates are not set up'; END IF;
  IF p_weight <= 0.5 THEN RETURN GREATEST(r.rate_half, r.min_fee); END IF;
  IF p_weight <= 1 THEN RETURN GREATEST(r.rate_one, r.min_fee); END IF;
  RETURN GREATEST(r.rate_one + ceil(p_weight - 1) * r.rate_extra, r.min_fee);
END $$;

-- One place that prices a cart: product/size prices, coupon, weight, zone, delivery and COD fee.
-- The 6% COD charge is added to the delivery fee, so shoppers only ever see one delivery figure.
CREATE OR REPLACE FUNCTION rb_quote(p_items jsonb, p_city text, p_method text, p_coupon text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_item jsonb; v_product products%ROWTYPE; v_qty integer; v_price numeric;
  v_subtotal numeric := 0; v_weight numeric := 0; v_pct integer; v_discount numeric;
  v_zone text; v_base numeric; v_cod numeric := 0; v_fee numeric;
  v_min_delivery constant numeric := 350;  -- the customer never pays less than this for delivery
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;
  FOR v_item IN SELECT jsonb_array_elements(p_items) LOOP
    SELECT * INTO v_product FROM products WHERE id = (v_item->>'product_id')::uuid AND is_active = true;
    IF NOT FOUND THEN RAISE EXCEPTION 'Product % is no longer available', v_item->>'product_name'; END IF;
    v_qty := (v_item->>'quantity')::integer;
    IF v_qty IS NULL OR v_qty < 1 THEN RAISE EXCEPTION 'Invalid quantity'; END IF;
    SELECT price_override INTO v_price FROM product_variants
      WHERE product_id = v_product.id AND lower(size) = lower(coalesce(v_item->>'size', '')) AND price_override IS NOT NULL
      ORDER BY (lower(color) = lower(coalesce(v_item->>'color', ''))) DESC LIMIT 1;
    v_subtotal := v_subtotal + coalesce(v_price, v_product.price) * v_qty;
    v_weight := v_weight + v_product.weight_kg * v_qty;
  END LOOP;
  v_pct := check_coupon(coalesce(p_coupon, ''));
  v_discount := round(v_subtotal * v_pct / 100.0);
  v_zone := zone_for_city(p_city);
  v_base := delivery_base_fee(v_zone, v_weight);
  IF p_method = 'Cash on Delivery' THEN
    v_cod := round((v_subtotal - v_discount + v_base) * 0.06);
  END IF;
  v_fee := GREATEST(v_min_delivery, v_base + v_cod);
  RETURN jsonb_build_object(
    'subtotal', v_subtotal, 'discount', v_discount, 'weight_kg', v_weight, 'zone', v_zone,
    'delivery_fee', v_fee, 'cod_fee', v_cod,
    'total', v_subtotal - v_discount + v_fee,
    'coupon', CASE WHEN v_pct > 0 THEN upper(p_coupon) END);
END $$;

-- What the checkout screen shows before the order is placed (subtotal, discount, delivery, total only).
CREATE OR REPLACE FUNCTION quote_delivery(p_items jsonb, p_city text, p_payment_method text, p_coupon text DEFAULT '') RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object('subtotal', q->'subtotal', 'discount', q->'discount', 'delivery_fee', q->'delivery_fee', 'total', q->'total')
  FROM (SELECT rb_quote(p_items, p_city, p_payment_method, p_coupon) AS q) s;
$$;
REVOKE EXECUTE ON FUNCTION rb_quote(jsonb, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION quote_delivery(jsonb, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION zone_for_city(text) TO anon, authenticated;

-- Replaces the earlier place_order. Everything money-related is decided here, not by the browser.
DROP FUNCTION IF EXISTS place_order(jsonb, text, text, text, text, text, text, text, uuid, numeric);
DROP FUNCTION IF EXISTS place_order(jsonb, text, text, text, text, text, text, text, uuid, text, double precision, double precision, text);
CREATE OR REPLACE FUNCTION place_order(
  p_items jsonb, p_customer_name text, p_email text, p_phone text, p_address text,
  p_city text DEFAULT '', p_postal_code text DEFAULT '', p_payment_method text DEFAULT 'Cash on Delivery',
  p_customer_id uuid DEFAULT NULL, p_coupon text DEFAULT '',
  p_lat double precision DEFAULT NULL, p_lng double precision DEFAULT NULL, p_payment_reference text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_order_id uuid; v_item jsonb; v_product products%ROWTYPE; v_qty integer; v_price numeric; v_q jsonb;
BEGIN
  IF p_payment_method NOT IN ('Cash on Delivery', 'Easypaisa') THEN RAISE EXCEPTION 'Unknown payment method'; END IF;
  IF p_payment_method = 'Easypaisa' AND length(trim(coalesce(p_payment_reference, ''))) < 6 THEN
    RAISE EXCEPTION 'Please enter your Easypaisa transaction ID';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN RAISE EXCEPTION 'Cart is empty'; END IF;

  -- Lock products and check stock first.
  FOR v_item IN SELECT jsonb_array_elements(p_items) LOOP
    SELECT * INTO v_product FROM products WHERE id = (v_item->>'product_id')::uuid AND is_active = true FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Product % is no longer available', v_item->>'product_name'; END IF;
    v_qty := (v_item->>'quantity')::integer;
    IF v_qty IS NULL OR v_qty < 1 THEN RAISE EXCEPTION 'Invalid quantity'; END IF;
    IF v_product.inventory < v_qty THEN
      RAISE EXCEPTION 'Not enough stock for %. Available: %, requested: %', v_product.name, v_product.inventory, v_qty;
    END IF;
  END LOOP;

  v_q := rb_quote(p_items, p_city, p_payment_method, p_coupon);

  INSERT INTO orders (customer_name, email, phone, address, city, postal_code, payment_method, status,
                      subtotal, discount, coupon_code, delivery_fee, cod_fee, total, weight_kg, delivery_zone,
                      latitude, longitude, payment_reference, customer_id)
  VALUES (p_customer_name, p_email, p_phone, p_address, p_city, p_postal_code, p_payment_method, 'pending',
          (v_q->>'subtotal')::numeric, (v_q->>'discount')::numeric, v_q->>'coupon',
          (v_q->>'delivery_fee')::numeric, (v_q->>'cod_fee')::numeric, (v_q->>'total')::numeric,
          (v_q->>'weight_kg')::numeric, v_q->>'zone', p_lat, p_lng, nullif(trim(coalesce(p_payment_reference, '')), ''), auth.uid())
  RETURNING id INTO v_order_id;

  FOR v_item IN SELECT jsonb_array_elements(p_items) LOOP
    v_qty := (v_item->>'quantity')::integer;
    SELECT * INTO v_product FROM products WHERE id = (v_item->>'product_id')::uuid;
    SELECT price_override INTO v_price FROM product_variants
      WHERE product_id = v_product.id AND lower(size) = lower(coalesce(v_item->>'size', '')) AND price_override IS NOT NULL
      ORDER BY (lower(color) = lower(coalesce(v_item->>'color', ''))) DESC LIMIT 1;
    INSERT INTO order_items (order_id, product_id, product_name, size, color, quantity, unit_price)
    VALUES (v_order_id, v_product.id, v_product.name, v_item->>'size', v_item->>'color', v_qty, coalesce(v_price, v_product.price));
    UPDATE products SET inventory = inventory - v_qty WHERE id = v_product.id;
  END LOOP;

  RETURN v_order_id;
END $$;
GRANT EXECUTE ON FUNCTION place_order(jsonb, text, text, text, text, text, text, text, uuid, text, double precision, double precision, text) TO anon, authenticated;


insert into admin_roles (user_id, role)
select id, 'super_admin' from auth.users where email = '230903@students.au.edu.pk'
on conflict (user_id) do update set role = 'super_admin';
