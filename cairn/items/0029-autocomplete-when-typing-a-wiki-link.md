---
id: 29
title: Autocomplete when typing a wiki link
type: feature
status: backlog
milestone: v0.4
labels:
- links
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: editor
---

Typing `[[` gives no help, so linking means remembering an exact title. In
Obsidian this popup is how the graph actually gets built — without it, people
stop linking.

## Acceptance criteria

- [ ] `[[` opens a popup filtered as you type, over titles, aliases and headings
- [ ] Return inserts the link, Escape dismisses without touching the text
- [ ] Arrow keys move the selection while the popup is open
- [ ] Offers to create the note when nothing matches
