---
id: 49
title: Renaming a note to change only its case creates a duplicate
type: bug
status: doing
milestone: v0.2
assignee: Oddur Sigurdsson
created: 2026-09-05
updated: 2026-09-06
priority: p1
effort: s
area: storage
---

`Vault.uniqueURL` guards with `FileManager.fileExists`, which on APFS is
case-insensitive by default. Renaming `note` to `Note` therefore finds the file
already there and hands back `Note 2.md` — so you end up with a second note
rather than a renamed one.

Verified: the boot volume reports APFS, and `fileExists` returns true for
`Note.md` when only `note.md` is on disk.

## Acceptance criteria

- [ ] A case-only rename renames the file
- [ ] Handled as the two-step move a case-insensitive volume requires
- [ ] Still refuses a rename that would collide with a genuinely different note
- [ ] A test that would fail on the current behaviour
