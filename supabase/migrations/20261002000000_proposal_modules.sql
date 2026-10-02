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
