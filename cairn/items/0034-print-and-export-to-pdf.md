---
id: 34
title: Print and export to PDF
type: feature
status: backlog
milestone: later
labels:
- parity
created: 2026-09-05
updated: 2026-09-05
priority: p2
effort: s
area: app
---

There is no File > Print and no export. The rendered note is right there in an
`NSTextView`, so printing it is mostly a matter of a print operation with the
right page setup — but the on-screen layout is sized for a window, not a page.

## Acceptance criteria

- [ ] ⌘P prints the note as it reads, not as source
- [ ] Export to PDF and to plain markdown
- [ ] Page margins and a sensible measure for print, not the window's
