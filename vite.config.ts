import { defineConfig, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath, URL } from 'node:url';

// The public address of the site, used in canonical links and share previews.
// Set VITE_SITE_URL on Vercel to your final address (for example https://www.example.com).
// Without it, Vercel's production address is used, and if neither exists the tags are left out.
function siteUrl(): string {
  const raw = process.env.VITE_SITE_URL || (process.env.VERCEL_PROJECT_PRODUCTION_URL ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}` : '');
  return raw.replace(/\/+$/, '');
}

function siteTags(): Plugin {
  return {
    name: 'rabbent-site-tags',
    transformIndexHtml(html) {
      const site = siteUrl();
      if (site) return html.replaceAll('__SITE__', site);
      return html
        .replace(/<script type="application\/ld\+json">[\s\S]*?<\/script>\s*/g, '')
        .split('\n')
        .filter((line) => !line.includes('__SITE__'))
        .join('\n');
    },
  };
}

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react(), siteTags()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  optimizeDeps: {
    exclude: ['lucide-react'],
  },
});
