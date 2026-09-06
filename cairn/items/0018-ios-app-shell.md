---
id: 18
title: iOS app shell
type: feature
status: backlog
milestone: v1.0
labels:
- ios
depends_on:
- 16
- 17
created: 2026-09-05
updated: 2026-09-05
priority: p0
effort: m
area: app
---

A navigation stack over the same vault: folders, note list, editor. The Mac uses a three-column NavigationSplitView; the phone wants a push navigation stack, and the iPad can use the split view as-is.

## Acceptance criteria

- [ ] Browse folders and tags, open a note, edit and autosave
- [ ] Swipe to delete, pull to refresh the index
- [ ] Reuses AppModel without forking it
