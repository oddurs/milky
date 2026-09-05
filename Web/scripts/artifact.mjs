// Astro emits a full HTML document; a published Artifact is wrapped in its own
// <head>/<body> at publish time and must therefore be body content only. This
// re-shapes the built page into that form so both targets share one source.
import { readFile, writeFile } from 'node:fs/promises';

const built = await readFile('dist/index.html', 'utf8');

const title = built.match(/<title>([\s\S]*?)<\/title>/)?.[1] ?? 'Milky';
const styles = [...built.matchAll(/<style[^>]*>[\s\S]*?<\/style>/g)].map((m) => m[0]);
const body = built.match(/<body[^>]*>([\s\S]*)<\/body>/)?.[1];

if (!body) throw new Error('No <body> found in dist/index.html — did the build succeed?');
if (!styles.length) throw new Error('No inlined <style> found; build.inlineStylesheets must stay "always".');

const out = [`<title>${title}</title>`, ...styles, body.trim(), ''].join('\n');

// A stray asset request would 404 inside the artifact sandbox.
const external = [...out.matchAll(/<(?:link|script)[^>]*(?:href|src)="([^"]+)"/g)].map((m) => m[1]);
if (external.length) throw new Error(`Artifact build is not self-contained: ${external.join(', ')}`);

await writeFile('dist/artifact.html', out);
console.log(`dist/artifact.html — ${(out.length / 1024).toFixed(1)} kB, ${styles.length} inlined style block(s)`);
