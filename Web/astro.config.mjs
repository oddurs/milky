import { defineConfig } from 'astro/config';

export default defineConfig({
  // Set this once the site has a domain — it turns the Open Graph image path
  // into the absolute URL that link scrapers require.
  // site: 'https://example.com',
  build: {
    // The built page is also published as a single self-contained artifact, so
    // no styling may live behind a separate asset request.
    inlineStylesheets: 'always',
  },
});
