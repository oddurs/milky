---
id: 20
title: Move the test suite onto XCTest
type: chore
status: backlog
milestone: v1.0
labels:
- testing
depends_on:
- 16
created: 2026-09-05
updated: 2026-09-05
priority: p2
effort: s
area: build
---

`Sources/MilkyTests` is a plain executable with a hand-rolled harness because the Command Line Tools ship a broken Testing.framework (no lib_TestingInterop.dylib) and no XCTest at all. Installing Xcode for the iOS work removes that constraint.

## Acceptance criteria

- [ ] Cases moved to a real test target, keeping every existing assertion
- [ ] `swift test` runs them
- [ ] CI updated to call it
