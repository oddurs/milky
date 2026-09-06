---
id: 47
title: Coordinate reads and writes with the system
type: feature
status: backlog
milestone: v0.2
labels:
- cloud
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: l
area: storage
---

Nothing in `Vault` uses `NSFileCoordinator` or registers an `NSFilePresenter`;
reads and writes are plain `String(contentsOf:)` and `String.write`.

For a local folder that is fine. For iCloud Drive it is the documented contract,
and skipping it means a write can land while the daemon is mid-sync — the class
of bug that shows up as a note losing a paragraph, weeks later, on someone
else's machine.

FSEvents is also the wrong watcher for iCloud: downloads and remote edits do not
reliably fire it. `NSMetadataQuery` is the tool for a ubiquitous container.

## Acceptance criteria

- [ ] Reads and writes go through `NSFileCoordinator`
- [ ] The open vault registers a file presenter
- [ ] iCloud vaults are watched with `NSMetadataQuery`, local ones with FSEvents
- [ ] `NSFileVersion.unresolvedConflictVersionsOfItem` is checked and surfaced

## Needs a real iCloud vault, and is worth doing carefully

The same constraint as `0046`, and more of it. `NSFileCoordinator` and
`NSFilePresenter` change how every read and write in the app behaves; getting
them wrong replaces a rare loss with a common deadlock. The failure mode this
prevents — a write landing mid-sync — cannot be reproduced without two machines
and a live container.

Do it after `0046`, with a real iCloud vault, and give it its own session.
