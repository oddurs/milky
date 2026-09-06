---
id: 11
title: Make search hold up on a large vault
type: feature
status: backlog
milestone: v0.5
labels:
- performance
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: storage
---

`AppModel.computeVisibleNotes` lowercases and substring-scans the full text of every note for every query. Fine for the four-note demo vault, not for a few thousand notes.

## Acceptance criteria

- [ ] An index built once on load and updated incrementally on save
- [ ] Typing in the search field stays responsive on a vault of 5,000 notes
- [ ] Measured before and after, with the numbers recorded on this item
