// Shared helpers for the search-engine pages. Files starting with "_" are not public URLs.

export const SUPABASE_URL = (process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL || '').replace(/\/+$/, '');
export const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY || '';

export function siteOrigin(req) {
  const fixed = (process.env.VITE_SITE_URL || '').replace(/\/+$/, '');
  if (fixed) return fixed;
  const host = req.headers['x-forwarded-host'] || req.headers.host || '';
  const proto = req.headers['x-forwarded-proto'] || (host.startsWith('localhost') ? 'http' : 'https');
  return `${String(proto).split(',')[0]}://${String(host).split(',')[0]}`;
}

export async function query(path) {
  if (!SUPABASE_URL || !SUPABASE_KEY) throw new Error('Supabase is not configured');
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` },
  });
  if (!res.ok) throw new Error(`Supabase answered ${res.status}`);
  return res.json();
}

export function esc(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// JSON placed inside a <script> tag must not be able to close it.
export function jsonForScript(obj) {
  return JSON.stringify(obj).replace(/</g, '\\u003c').replace(/>/g, '\\u003e').replace(/&/g, '\\u0026');
}

export function clip(text, max) {
  const clean = String(text ?? '').replace(/\s+/g, ' ').trim();
  return clean.length > max ? `${clean.slice(0, max - 1).trimEnd()}…` : clean;
}

let cached = { at: 0, html: '' };
// The built shop page (with its script and style links) that every product page is based on.
export async function shopShell(origin) {
  if (cached.html && Date.now() - cached.at < 60_000) return cached.html;
  const res = await fetch(`${origin}/index.html`, { headers: { 'x-rabbent-internal': '1' } });
  if (!res.ok) throw new Error(`Could not load the shop page (${res.status})`);
  const html = await res.text();
  if (!html.includes('<div id="root">')) throw new Error('Unexpected shop page');
  cached = { at: Date.now(), html };
  return html;
}
