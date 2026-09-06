---
id: 48
title: The watcher rebuilds the index on every git write
type: bug
status: doing
milestone: v0.2
assignee: Oddur Sigurdsson
labels:
- sync
created: 2026-09-05
updated: 2026-09-06
priority: p1
effort: s
area: storage
---

`Vault.ignoredDirectories` keeps `.git` out of the *scan*, but `VaultWatcher`
hands FSEvents the vault root with no exclusions. Every git operation writes
`.git/index`, `.git/ORIG_HEAD` and friends, so a sync triggers the debounce,
which triggers a full rescan — reading every file in the vault — while git is
still working.

## Acceptance criteria

- [ ] Events under `.git` and other ignored directories are dropped
- [ ] A sync causes at most one reindex, after it finishes
- [ ] The ignore list is shared with `Vault`, not duplicated
