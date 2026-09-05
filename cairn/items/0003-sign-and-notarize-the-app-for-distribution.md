---
id: 3
title: Sign and notarize the app for distribution
type: chore
status: planned
milestone: v0.1
labels:
- release
created: 2026-09-05
updated: 2026-09-05
priority: p0
effort: m
area: build
---

`Scripts/bundle.sh` signs ad-hoc (`codesign --sign -`). That is fine locally and useless everywhere else: Gatekeeper blocks the app on any Mac that did not build it, which makes a download link pointless until this is fixed.

## Acceptance criteria

- [ ] Signed with a Developer ID Application certificate
- [ ] Hardened runtime enabled (`--options runtime`)
- [ ] Submitted with `notarytool` and the ticket stapled to the bundle
- [ ] Verified with `spctl --assess` on a Mac that never built it
