---
id: 19
title: Open an iCloud Drive vault on iOS
type: feature
status: backlog
milestone: v1.0
labels:
- ios
depends_on:
- 16
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: m
area: storage
---

On the Mac a vault is any directory and iCloud is just a path. On iOS the same folder is reached through the document picker with security-scoped URLs, and `VaultWatcher` uses FSEvents, which does not exist there.

## Acceptance criteria

- [ ] Pick a vault through UIDocumentPicker and keep access across launches
- [ ] File coordination and presentation in place of FSEvents
- [ ] A note edited on the Mac appears on the phone without a relaunch
