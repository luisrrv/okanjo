import { defineConfig } from 'vite';

// Served by the Rails app at warikan.lrod.dev/liff (ADR 0024), so built asset URLs start
// with /liff/.
export default defineConfig({
  base: '/liff/',
});
