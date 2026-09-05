---
id: 6
title: Present the appearance controls
type: feature
status: done
milestone: v0.1
assignee: Oddur Sigurdsson
labels:
- editor
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: s
area: app
---

`AppearancePopover` exists in MilkyUI and nothing ever presents it, so it is dead code. Today the reading face can only be changed by editing UserDefaults, and the text size only through the View menu shortcuts.

## Acceptance criteria

- [ ] A toolbar control opens the popover
- [ ] Switching between San Francisco and New York restyles the open note immediately
- [ ] The choice survives a relaunch (it already persists; verify the path works)
