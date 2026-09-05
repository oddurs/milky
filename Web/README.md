# Milky landing page

An Astro site, one page, no dependencies beyond Astro itself and no webfonts.

```bash
npm install
npm run dev      # http://localhost:4321
npm run build    # → dist/
```

The app window in the hero (`src/components/AppWindow.astro`) is real DOM rather
than a screenshot: it stays crisp at any resolution, follows the reader's light or
dark theme, and renders the sidebar that an in-process screen capture cannot.

`build.inlineStylesheets: 'always'` plus `is:inline` on both scripts keeps
`dist/index.html` a single self-contained file, which is what lets the same build
be published as an Artifact.

`public/og.png` is the link-preview card, rendered from the page's own hero with
headless Chrome. Regenerate it after a hero change; set `site` in
`astro.config.mjs` to turn the `og:image` path into the absolute URL scrapers
require.

Colour and type tokens live in `src/styles/tokens.css`; shared element and layout
roles in `src/styles/base.css`. Everything else is scoped to its component.
