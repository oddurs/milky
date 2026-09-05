---
id: 33
title: Callouts
type: feature
status: backlog
milestone: later
labels:
- markdown
created: 2026-09-05
updated: 2026-09-05
priority: p2
effort: m
area: editor
---

`> [!note]` blocks are everywhere in Obsidian vaults and would currently render
as a blockquote whose first line reads `[!note]`.

The block decoration machinery already draws quote bars and code grounds, so this
is a tinted variant of something that exists.

## Acceptance criteria

- [ ] `note`, `tip`, `warning`, `danger`, `quote` types with distinct tint and symbol
- [ ] The `[!type]` marker dims like other syntax
- [ ] An unknown type falls back to a plain blockquote rather than breaking
- [ ] Tints come from tokens and pass contrast in both appearances
