---
id: 13
title: Pin notes to the top of the list
type: feature
status: backlog
milestone: v0.2
labels:
- parity
created: 2026-09-05
updated: 2026-09-05
priority: p2
effort: s
area: app
---

Apple Notes pins; Milky does not. Pinning has to live in the file rather than a sidecar database, so it needs a frontmatter convention that other editors will not trip over.

## Acceptance criteria

- [ ] Pinned notes sort above the rest under a header
- [ ] The flag round-trips through the file, not app state
- [ ] Opening the vault in another editor shows nothing surprising
