import type { Product } from '@/lib/types';

export const DEFAULT_TITLE = 'Rabbent | Caps, apparel and PAF models with cash on delivery';
export const DEFAULT_DESCRIPTION = 'Shop Rabbent for caps, apparel, souvenirs and PAF aircraft models. Pay cash on delivery or by Easypaisa. Delivered across Pakistan from Sargodha.';

export const productPath = (p: Product) => `/product/${encodeURIComponent(p.slug || p.id)}`;
export const productKey = (p: Product) => p.slug || p.id;

function setMeta(selector: string, create: () => HTMLElement, attr: string, value: string) {
  let el = document.head.querySelector<HTMLElement>(selector);
  if (!el) { el = create(); document.head.appendChild(el); }
  el.setAttribute(attr, value);
}

const meta = (name: string) => () => { const m = document.createElement('meta'); m.setAttribute('name', name); return m; };
const prop = (name: string) => () => { const m = document.createElement('meta'); m.setAttribute('property', name); return m; };

// Keeps the browser tab, bookmarks and shared links in step with what is on screen.
export function setPageMeta(opts: { title: string; description: string; path: string; image?: string }) {
  document.title = opts.title;
  const url = `${window.location.origin}${opts.path}`;
  setMeta('meta[name="description"]', meta('description'), 'content', opts.description);
  setMeta('link[rel="canonical"]', () => { const l = document.createElement('link'); l.rel = 'canonical'; return l; }, 'href', url);
  setMeta('meta[property="og:title"]', prop('og:title'), 'content', opts.title);
  setMeta('meta[property="og:description"]', prop('og:description'), 'content', opts.description);
  setMeta('meta[property="og:url"]', prop('og:url'), 'content', url);
  if (opts.image) setMeta('meta[property="og:image"]', prop('og:image'), 'content', opts.image);
}

export const clip = (text: string, max: number) => {
  const clean = (text || '').replace(/\s+/g, ' ').trim();
  return clean.length > max ? `${clean.slice(0, max - 1).trimEnd()}…` : clean;
};
