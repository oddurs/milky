---
id: 46
title: iCloud files that are not downloaded are invisible
type: bug
status: backlog
milestone: v0.2
labels:
- cloud
depends_on:
- 45
created: 2026-09-05
updated: 2026-09-05
priority: p0
effort: m
area: storage
---

An evicted iCloud Drive file is a hidden placeholder named `.Note.md.icloud`,
and `Vault.scan` enumerates with `.skipsHiddenFiles`. The note simply is not
there — no error, no gap in the list, nothing to notice.

Same symptom as `0021` and a different cause: there the file could not be read,
here it is not recognised as a file at all. For a vault in iCloud Drive — one of
the four options the welcome screen offers — this makes the app quietly wrong.

## Acceptance criteria

- [ ] Placeholders are recognised and listed as notes
- [ ] Opening one downloads it, with something on screen saying so
- [ ] `URLUbiquitousItemDownloadingStatusKey` drives the state, not the filename
- [ ] A vault with every file evicted still shows the right count
