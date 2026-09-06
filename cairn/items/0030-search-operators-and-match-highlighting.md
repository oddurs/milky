---
id: 30
title: Search operators and match highlighting
type: feature
status: backlog
milestone: v0.5
labels:
- search
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: storage
---

Search is a lowercased substring test over title and body. There is no way to
scope it, and results give no indication of *where* the match was — the row shows
the note's first line, not the matching one.

## Acceptance criteria

- [ ] `tag:`, `path:`, `title:` and quoted phrases
- [ ] Result rows show the matching line with the term marked
- [ ] Matches are marked in the editor when a note is opened from a search
- [ ] Runs against the index from 0011, not a linear scan
