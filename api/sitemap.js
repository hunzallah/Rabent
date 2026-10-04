import { query, siteOrigin, esc } from './_shared.js';

// Lists the home page and every active product so Google can find them.
export default async function handler(req, res) {
  const origin = siteOrigin(req);
  let products = [];
  try {
    products = await query('products?select=slug,created_at&is_active=eq.true&order=created_at.desc&limit=5000');
  } catch {
    // Still answer with the home page so the sitemap never breaks.
  }
  const urls = [`<url><loc>${esc(origin)}/</loc><changefreq>daily</changefreq><priority>1.0</priority></url>`];
  for (const p of products) {
    if (!p.slug) continue;
    urls.push(`<url><loc>${esc(origin)}/product/${esc(encodeURIComponent(p.slug))}</loc><changefreq>weekly</changefreq><priority>0.8</priority></url>`);
  }
  res.setHeader('Content-Type', 'application/xml; charset=utf-8');
  res.setHeader('Cache-Control', 'public, s-maxage=3600, stale-while-revalidate=86400');
  res.status(200).send(`<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.join('\n')}\n</urlset>\n`);
}
