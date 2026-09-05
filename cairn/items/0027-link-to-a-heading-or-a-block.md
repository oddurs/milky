---
id: 27
title: Link to a heading or a block
type: feature
status: backlog
milestone: v0.2
labels:
- links
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: editor
---

`followWikiLink` compares the target to note titles and nothing else, so
`[[Note#Heading]]` and `[[Note^block-id]]` — both everyday Obsidian — resolve to
the note at best and fail at worst. The tokenizer already captures the whole
target including the `#`.

## Acceptance criteria

- [ ] `[[Note#Heading]]` opens the note and scrolls that heading into view
- [ ] `[[Note#^block-id]]` resolves a block reference
- [ ] An unresolved heading opens the note rather than failing silently
- [ ] Ambiguous titles in different folders resolve by path, then prompt
