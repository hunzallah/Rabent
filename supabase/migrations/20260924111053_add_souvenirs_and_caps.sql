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