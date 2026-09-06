---
id: 45
title: Opening a vault reads every file on the main thread
type: bug
status: done
milestone: v0.2
assignee: Oddur Sigurdsson
labels:
- cloud
created: 2026-09-05
updated: 2026-09-06
priority: p0
effort: m
area: storage
---

`Vault.scan` calls `String(contentsOf:)` for every markdown file it walks, and
`AppModel` is `@MainActor` with a synchronous `reload()`. So opening a vault
reads the entire corpus on the main thread, and every external change does it
again.

Locally that is merely slow. On Dropbox with online-only files, or iCloud with
evicted ones, reading a placeholder *forces a download* — so opening a vault
pulls the whole thing over the network while the window is frozen.

## Acceptance criteria

- [ ] Indexing runs off the main thread and reports progress
- [ ] The list is built from filesystem metadata; contents load lazily
- [ ] A file that is not local is listed without being downloaded
- [ ] Reindexing after an external change touches only what changed
