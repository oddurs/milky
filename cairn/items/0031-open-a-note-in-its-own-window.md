---
id: 31
title: Open a note in its own window
type: feature
status: backlog
milestone: v0.8
labels:
- parity
created: 2026-09-05
updated: 2026-09-05
priority: p2
effort: m
area: app
---

The app is a single `Window` scene and tabbing is explicitly disallowed in
`WindowAccessor`. Apple Notes opens a note in its own window on double-click,
which is how people put two notes side by side.

## Acceptance criteria

- [ ] Double-clicking a row opens that note in a new window
- [ ] Editing the same note in two windows stays consistent
- [ ] Each window remembers its own frame
