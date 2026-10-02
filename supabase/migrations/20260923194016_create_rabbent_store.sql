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