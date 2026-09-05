---
id: 7
title: Point the download buttons at a real release
type: chore
status: blocked
milestone: v0.1
labels:
- release
depends_on:
- 3
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: s
area: site
---

Both 'Download for Mac' buttons on the landing page href to `#`. The page promises a download that does not exist.

## Acceptance criteria

- [ ] Both buttons link to the published DMG
- [ ] 'Build from source' links to the repository
- [ ] The stated macOS requirement matches what the build actually targets

## Wired, but nothing to download yet

Both buttons now point at `https://github.com/oddurs/milky/releases/latest` and
"Build from source" at the repository, from `Web/src/site.ts`. Deployed and
verified at <https://oddurs.github.io/milky/>.

That URL returns 200, but it is GitHub's empty releases page: there is no DMG to
download until `0003` clears and a release is cut. Re-pointed to depend on `0003`
rather than `0005` — the disk image builds fine, it just cannot be distributed
unsigned.

Closes when `gh release create v0.1.0 release/Milky-0.1.0.dmg` has run and the
button reaches an actual download.
