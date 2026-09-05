---
id: 28
title: Read frontmatter as properties, and support aliases
type: feature
status: backlog
milestone: v0.2
labels:
- links
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: storage
---

Frontmatter is tokenized and styled, and then never read. Nothing parses it, so
`aliases:` does nothing, `tags:` in frontmatter is invisible next to inline
`#tags`, and there is no notion of a note property at all.

Aliases matter most: without them a note can only be linked by its exact
filename, which is why people rename notes and break their links.

## Acceptance criteria

- [ ] Parse YAML frontmatter into typed properties on `Note`
- [ ] `aliases` resolve in `[[wiki links]]` and in search
- [ ] Frontmatter `tags` merge with inline ones in the sidebar
- [ ] A malformed block is reported, not crashed on, and never rewritten
