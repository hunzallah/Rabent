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
