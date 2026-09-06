---
id: 39
title: Focus mode
type: feature
status: backlog
milestone: v0.7
labels:
- writing
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: s
area: editor
---

iA Writer's signature: everything except the sentence or paragraph you are in
fades back, so the page falls away around the line you are writing. Nothing in
the Obsidian or Bear space does this well, and it is the clearest reason to
write in Milky rather than in a text editor.

Nearly free here. `MilkyTextView.activeParagraphRange()` is already computed on
every caret move to drive the syntax reveal — focus mode is the same range with
a different attribute applied to its complement.

## Acceptance criteria

- [ ] Paragraph and sentence granularity, off by default
- [ ] Everything outside the focus dims rather than hiding; nothing reflows
- [ ] The dim animates over `Motion.quick` and no-ops under reduced motion
- [ ] Reuses the existing active-paragraph tracking rather than a second mechanism
