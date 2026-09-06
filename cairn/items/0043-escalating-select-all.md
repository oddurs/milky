---
id: 43
title: Escalating select all
type: feature
status: backlog
milestone: v0.3
labels:
- parity
created: 2026-09-05
updated: 2026-09-05
priority: p3
effort: s
area: editor
---

Notion's ⌘A escalates: the block's text, then the block, then the document.
Today the first ⌘A takes the whole note, so there is no keyboard way to select
just the paragraph you are in.

## Acceptance criteria

- [ ] First ⌘A selects the current paragraph, second the whole note
- [ ] The escalation resets when the caret moves
