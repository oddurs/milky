---
id: 42
title: Drag a block to reorder it
type: feature
status: backlog
milestone: v0.3
labels:
- parity
created: 2026-09-05
updated: 2026-09-05
priority: p2
effort: m
area: editor
---

Notion's `⋮⋮` handle. Reordering a list item or a paragraph currently means
selecting the line, cutting, and pasting somewhere else — the single clumsiest
thing in the editor.

The decoration machinery already draws in the margin (bullets, checkboxes,
quote bars), so a handle on the hovered block is the same mechanism.

## Acceptance criteria

- [ ] A grab handle appears in the margin of the hovered block
- [ ] Dragging moves the whole block, list item and its continuation lines together
- [ ] A drop indicator shows where it will land
- [ ] One undo step, not one per line
