---
id: 50
title: A merge conflict leaves you in the terminal
type: feature
status: backlog
milestone: v0.2
labels:
- sync
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: storage
---

`GitSync.sync` runs `pull --rebase --autostash`, and on failure calls
`rebase --abort` and throws git's stderr into an alert. Nothing is lost, which
is the important part — but the reader is told "CONFLICT (content): Merge
conflict in Note.md" and given no way forward inside the app.

Conflict markers in a note would also render as prose, since the tokenizer has
no idea what `<<<<<<<` means.

## Acceptance criteria

- [ ] A conflict is explained in the app's own words, naming the notes affected
- [ ] Per note: keep mine, take theirs, or keep both as separate notes
- [ ] Conflict markers are recognised and marked in the editor
- [ ] The abort path stays the default, so an unresolved conflict never blocks writing
