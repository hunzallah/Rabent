import { query, siteOrigin, shopShell, esc, jsonForScript, clip } from './_shared.js';

// One crawlable page per product: its own title, description, share image and structured data.
// The normal shop app still loads on top of it, so shoppers see the usual page.
export default async function handler(req, res) {
  const origin = siteOrigin(req);
  const slug = String(req.query.slug || '').trim();
  let product = null;
  let variantPrices = [];

  try {
    if (slug) {
      const rows = await query(`products?slug=eq.${encodeURIComponent(slug)}&is_active=eq.true&select=id,name,slug,description,price,compare_at_price,image_url,inventory&limit=1`);
      product = rows[0] || null;
      if (product) {
        const variants = await query(`product_variants?product_id=eq.${encodeURIComponent(product.id)}&select=price_override&price_override=not.is.null`).catch(() => []);
        variantPrices = variants.map((v) => Number(v.price_override)).filter((n) => Number.isFinite(n) && n > 0);
      }
    }
  } catch {
    // Fall through: show the shop without product details rather than an error page.
  }

  let shell;
  try {
    shell = await shopShell(origin);
  } catch {
    res.setHeader('Location', '/');
    res.status(302).end();
    return;
  }

  const url = `${origin}/product/${encodeURIComponent(slug)}`;
  let head;
  let body;
  let status = 200;

  if (!product) {
    status = 404;
    head = `<title>Product not found | Rabbent</title><meta name="robots" content="noindex" />`;
    body = `<main><h1>Product not found</h1><p>This product is no longer available. <a href="/">See everything in the shop</a>.</p></main>`;
  } else {
    const price = Number(product.price);
    const prices = [price, ...variantPrices];
    const low = Math.min(...prices);
    const high = Math.max(...prices);
    const inStock = Number(product.inventory) > 0;
    const description = clip(product.description, 155) || `Buy ${product.name} from Rabbent. Cash on delivery or Easypaisa, delivered across Pakistan.`;
    const title = `${product.name} | Rabbent`;
    const availability = inStock ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock';
    const offers = low !== high
      ? { '@type': 'AggregateOffer', priceCurrency: 'PKR', lowPrice: low, highPrice: high, offerCount: prices.length, availability, url }
      : { '@type': 'Offer', priceCurrency: 'PKR', price: low, availability, url, itemCondition: 'https://schema.org/NewCondition' };
    const ld = {
      '@context': 'https://schema.org',
      '@type': 'Product',
      name: product.name,
      description: clip(product.description, 500) || product.name,
      url,
      brand: { '@type': 'Brand', name: 'Rabbent' },
      ...(product.image_url ? { image: [product.image_url] } : {}),
      offers,
    };
    head = [
      `<title>${esc(title)}</title>`,
      `<meta name="description" content="${esc(description)}" />`,
      `<link rel="canonical" href="${esc(url)}" />`,
      `<meta property="og:type" content="product" />`,
      `<meta property="og:site_name" content="Rabbent" />`,
      `<meta property="og:title" content="${esc(title)}" />`,
      `<meta property="og:description" content="${esc(description)}" />`,
      `<meta property="og:url" content="${esc(url)}" />`,
      product.image_url ? `<meta property="og:image" content="${esc(product.image_url)}" />` : '',
      `<meta name="twitter:card" content="summary_large_image" />`,
      `<meta name="twitter:title" content="${esc(title)}" />`,
      `<meta name="twitter:description" content="${esc(description)}" />`,
      product.image_url ? `<meta name="twitter:image" content="${esc(product.image_url)}" />` : '',
      `<script type="application/ld+json">${jsonForScript(ld)}</script>`,
    ].filter(Boolean).join('\n    ');
    body = `<main><h1>${esc(product.name)}</h1>${product.image_url ? `<img src="${esc(product.image_url)}" alt="${esc(product.name)}" width="480" />` : ''}<p>Rs. ${esc(low.toLocaleString('en-PK'))}${low !== high ? ` to Rs. ${esc(high.toLocaleString('en-PK'))}` : ''}</p><p>${esc(clip(product.description, 500))}</p><p><a href="/">Back to the Rabbent shop</a></p></main>`;
  }

  // Replace the home page's own title, description, canonical and share tags with this product's.
  const html = shell
    .replace(/<title>[\s\S]*?<\/title>/, '')
    .replace(/<meta name="description"[^>]*>\s*/g, '')
    .replace(/<link rel="canonical"[^>]*>\s*/g, '')
    .replace(/<meta (?:property="og:|name="twitter:)[^>]*>\s*/g, '')
    .replace(/<script type="application\/ld\+json">[\s\S]*?<\/script>\s*/g, '')
    .replace('</head>', `    ${head}\n  </head>`)
    .replace(/<div id="root">[\s\S]*?<\/div>\s*(?=<noscript>|<script)/, `<div id="root">${body}</div>\n    `);

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', status === 200 ? 'public, s-maxage=300, stale-while-revalidate=3600' : 'public, s-maxage=60');
  res.status(status).send(html);
}
