---
id: 24
title: Sort and group the note list
type: feature
status: backlog
milestone: v0.3
labels:
- parity
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: app
---

Notes come back from `Vault.reload` sorted by modification date and there is no
other option. Apple Notes offers sort by date edited, date created or title, and
groups the list under Pinned / Today / Yesterday / Previous 7 Days / Previous 30
Days / by month.

The grouping is most of what makes that list scannable, and it is the single
most visible difference between our list and Notes'.

## Acceptance criteria

- [ ] Sort by date edited, date created or title, remembered per vault
- [ ] Date grouping with sticky section headers
- [ ] Grouping turns off when sorting by title
- [ ] Works with search results and with a folder or tag selected
