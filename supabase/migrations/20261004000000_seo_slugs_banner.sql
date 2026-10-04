-- 7: search-friendly product links and honest banner text. Safe to run more than once.
update products
set slug = trim(both '-' from regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g'))
where slug is null or slug = '' or slug ~ '[^a-z0-9-]';

-- the old banner promised free delivery, but delivery is always charged
update banners set subtitle = 'Cash on delivery across Pakistan'
where subtitle ilike 'Free delivery%';
