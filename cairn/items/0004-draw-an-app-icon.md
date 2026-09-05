---
id: 4
title: Draw an app icon
type: feature
status: done
milestone: v0.1
assignee: Oddur Sigurdsson
labels:
- release
created: 2026-09-05
updated: 2026-09-05
priority: p0
effort: s
area: app
---

The bundle has no `CFBundleIconFile`, so the Dock and Finder show a generic placeholder.

The landing page mark is a yellow rounded square with three note lines; the icon should come from the same idea rather than being invented separately.

## Acceptance criteria

- [ ] `Milky.icns` with every size macOS asks for
- [ ] `CFBundleIconFile` set in the generated Info.plist
- [ ] Reads correctly at 16pt in the Finder sidebar
