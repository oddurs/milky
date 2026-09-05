---
id: 12
title: Show images in the editor
type: feature
status: backlog
milestone: v0.2
labels:
- markdown
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: editor
---

`![alt](path)` tokenizes as a link and renders as text. Notes with screenshots are unreadable, which rules out the most common reason people paste into Apple Notes.

## Acceptance criteria

- [ ] Relative image paths render inline, scaled to the measure
- [ ] Pasting an image writes the file into the vault and inserts the markdown
- [ ] The line still reveals its markdown when the cursor enters it
