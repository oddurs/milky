---
id: 23
title: Checkboxes are drawn but not clickable
type: feature
status: doing
milestone: v0.3
assignee: Oddur Sigurdsson
labels:
- parity
created: 2026-09-05
updated: 2026-09-06
priority: p0
effort: s
area: editor
---

`MilkyTextView.drawBackground` renders task checkboxes, and `mouseDown` only
routes to links — so clicking a checkbox does nothing. In Apple Notes clicking
the circle *is* the interaction; typing `x` between brackets is not something
anyone should have to do.

The marker range is already known: `MarkerGlyph.checkboxOpen` / `.checkboxDone`
carry it into the decoration list.

## Acceptance criteria

- [ ] Clicking a checkbox toggles `[ ]` ↔ `[x]` in the text
- [ ] The change goes through the undo stack, like any edit
- [ ] The pointer becomes a hand over the box
- [ ] Clicking the text of the line still places the caret
