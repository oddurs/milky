---
id: 7
title: Point the download buttons at a real release
type: chore
status: planned
milestone: v0.1
labels:
- release
depends_on:
- 5
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
