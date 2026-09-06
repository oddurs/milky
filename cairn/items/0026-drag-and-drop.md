---
id: 26
title: Drag and drop
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

Nothing in the app registers a drag type. Moving a note between folders means the
context menu; getting a file in means Finder.

## Acceptance criteria

- [ ] Drag a note from the list onto a sidebar folder to move it
- [ ] Drag a folder onto another to nest it
- [ ] Drop a `.md` file onto the window to import it into the current folder
- [ ] Drop an image into the editor to file it and insert the markdown
      (depends on attachments, 0012)
