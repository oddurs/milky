---
id: 16
title: Generate an Xcode project for the iOS target
type: chore
status: backlog
milestone: v1.0
labels:
- ios
created: 2026-09-05
updated: 2026-09-05
priority: p0
effort: m
area: build
---

The Mac app is a SwiftPM executable wrapped into a bundle by `Scripts/bundle.sh`, built against the Command Line Tools SDK. That path cannot produce an iOS app: no simulator, no device signing, no app target.

## Acceptance criteria

- [ ] Xcode installed, and the project generated rather than hand-maintained (XcodeGen or Tuist)
- [ ] Mac and iOS targets both consume MilkyCore, MilkyStorage and MilkyUI
- [ ] The generated project is reproducible from a checked-in manifest, not committed as an opaque pbxproj
