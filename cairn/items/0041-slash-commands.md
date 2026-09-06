---
id: 41
title: Slash commands
type: feature
status: backlog
milestone: v0.7
labels:
- writing
depends_on:
- 9
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: editor
---

Notion's `/`. Type a slash at the start of an empty line and pick a block type:
heading, list, checklist, quote, code, table, divider, math.

Milky already turns markdown into formatting as you type — `## ` is a heading
the moment you type it. What it has no answer for is *discovery*: nothing tells
a new reader that a table or a callout is available at all. A slash menu is how
Notion made a document format learnable without a manual.

Shares its component with the quick switcher (0009) and the command palette
(0032) — one filtered list over three different indexes.

## Acceptance criteria

- [ ] `/` on an empty line opens a filtered menu; typing narrows it
- [ ] Return inserts the markdown, Escape leaves the slash as literal text
- [ ] Never fires mid-word, or inside code and math
- [ ] Each entry shows the markdown it inserts, so it teaches the syntax
