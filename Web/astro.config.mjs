import { defineConfig } from 'astro/config';

export default defineConfig({
  // GitHub Pages serves a project repo from a subpath, so `base` has to be set
  // and every root-absolute asset path has to go through import.meta.env.BASE_URL.
  // Both collapse to '/' if this ever moves to a custom domain.
  site: 'https://oddurs.github.io',
  base: '/milky',
  build: {
    // The built page is also published as a single self-contained artifact, so
    // no styling may live behind a separate asset request.
    inlineStylesheets: 'always',
  },
});
