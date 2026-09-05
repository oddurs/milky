---
id: 37
title: Embed one note inside another
type: feature
status: backlog
milestone: later
labels:
- links
created: 2026-09-05
updated: 2026-09-05
priority: p3
effort: m
area: editor
---

`![[Note]]` and `![[image.png]]` are how Obsidian composes notes. Today the
tokenizer reads them as an image-style link.

Depends on inline images (0012), and on deciding what an embed does when the
caret enters its line — the reveal model has to keep working.

## Acceptance criteria

- [ ] `![[Note]]` renders that note's content inline, marked as an embed
- [ ] `![[image.png]]` renders the image
- [ ] Cycles are detected rather than recursed into
