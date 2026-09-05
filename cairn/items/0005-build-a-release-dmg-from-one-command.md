---
id: 5
title: Build a release DMG from one command
type: chore
status: done
milestone: v0.1
labels:
- release
depends_on:
- 3
created: 2026-09-05
updated: 2026-09-05
priority: p0
effort: m
area: build
---

Packaging is currently a developer running `Scripts/bundle.sh` and getting a bare `.app`. A release needs a disk image people can mount and drag.

## Acceptance criteria

- [ ] `Scripts/release.sh <version>` produces a signed, notarized, stapled DMG
- [ ] The version comes from one place, not three
- [ ] The DMG opens to the app and an Applications alias
