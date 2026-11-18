import { defineConfig } from 'vite';

// Served by the Rails app at warikan.lrod.dev/liff (ADR 0024), so built asset URLs start
// with /liff/. In development, API calls go to the Rails app on port 3000.
export default defineConfig({
  base: '/liff/',
  server: {
    proxy: { '/api': 'http://localhost:3000' },
  },
});
