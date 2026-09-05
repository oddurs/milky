---
id: 10
title: Show backlinks for the open note
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

`Note.outboundLinks` already parses `[[wiki links]]`, but nothing surfaces the reverse direction, so a note cannot tell you what points at it.

## Acceptance criteria

- [ ] A collapsible section under the editor lists notes linking here
- [ ] The index updates when a link is added or removed
- [ ] Clicking a backlink opens that note
