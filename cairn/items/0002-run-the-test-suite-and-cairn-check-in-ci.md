---
id: 2
title: Run the test suite and cairn check in CI
type: chore
status: done
milestone: v0.1
assignee: Oddur Sigurdsson
labels:
- ci
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: s
area: build
---

Nothing verifies the build on a clean machine. The suite is an executable (`swift run milky-tests`) because neither Swift Testing nor XCTest works without Xcode, so CI must call it that way.

## Acceptance criteria

- [ ] A workflow builds the package and runs `swift run milky-tests`
- [ ] `cairn check` and `cairn render --check` run on every push
- [ ] The Astro site builds
