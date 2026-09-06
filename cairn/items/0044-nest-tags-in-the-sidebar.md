---
id: 44
title: Nest tags in the sidebar
type: feature
status: backlog
milestone: v0.4
labels:
- navigation
created: 2026-09-05
updated: 2026-09-05
priority: p2
effort: s
area: app
---

Bear nests tags on `/`: `#work/milky` sits under `work`. The tokenizer already
accepts slashes — `#([A-Za-z][\w/-]*)` — and `Note.tags` returns `work/milky`
intact. The sidebar then lists them flat, so a vault with any tag discipline
gets a long alphabetical column instead of a tree.

`FolderNode.tree(from:)` in `SidebarView` already builds exactly this shape from
`/`-separated paths for folders. This is that function pointed at a second input.

## Acceptance criteria

- [ ] Tags nest on `/`, collapsible like folders
- [ ] A parent counts every note under it, not just exact matches
- [ ] Selecting a parent shows the whole subtree
- [ ] Expansion state survives a relaunch
