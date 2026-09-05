---
id: 22
title: An external change is silently discarded while you are typing
type: bug
status: backlog
milestone: v0.2
labels:
- reliability
created: 2026-09-05
updated: 2026-09-05
priority: p0
effort: m
area: storage
---

`AppModel.handleExternalChange` only takes the on-disk version when the buffer is
clean:

    if !isDirty, let note = ..., note.text != draft { draft = note.text }

If the note is dirty *and* the file changed underneath — a `git pull`, a Dropbox
sync, the same note edited on another machine — the disk version is dropped
without a word, and the 700 ms autosave then overwrites it. For an app whose
entire pitch is "keep your notes in a folder something else syncs", this is the
worst failure it can have.

## Acceptance criteria

- [ ] Detect that the file changed on disk since it was loaded (compare modification
      date and content, not just the flag)
- [ ] With unsaved edits, do not overwrite: tell the reader and offer to keep
      theirs, take the incoming one, or write the incoming one beside it
- [ ] Never resolve silently in either direction
- [ ] A test that simulates a concurrent write and asserts nothing is lost
