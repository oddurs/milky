---
id: 25
title: Folders can be created but never renamed, moved or deleted
type: feature
status: backlog
milestone: v0.2
labels:
- parity
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: storage
---

`Vault` has `createFolder` and nothing else, and `SidebarView` has no context
menu at all. A folder made by mistake can only be fixed in Finder — which
undercuts the whole point of the app being a comfortable front end to a folder.

## Acceptance criteria

- [ ] Context menu on a sidebar folder: rename, move to, delete, reveal in Finder
- [ ] Renaming a folder updates the notes underneath it
- [ ] Deleting a non-empty folder says how many notes go with it
- [ ] Deletes go to the Finder trash, like notes do
