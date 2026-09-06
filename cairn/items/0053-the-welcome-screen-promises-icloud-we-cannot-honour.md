---
id: 53
title: The welcome screen promises iCloud we cannot honour
type: bug
status: done
milestone: v0.1
assignee: Oddur Sigurdsson
labels:
- cloud
- release
created: 2026-09-05
updated: 2026-09-06
priority: p0
effort: s
area: app
---

`WelcomeView` offers iCloud Drive as one of four equal choices, under the
subtitle **"Syncs to your iPhone automatically"**. Both halves of that are
currently untrue:

- iCloud vaults are not handled correctly. An evicted file is invisible (`0046`)
  and nothing coordinates reads and writes (`0047`), so the one option we
  advertise most confidently is the one most likely to lose or hide a note.
- There is no iPhone app. It is `v1.0`, roughly a year out.

This is the first screen anybody sees, and it is the app making a claim it
cannot keep. Either the claim goes or the support arrives — but shipping `v0.1`
with this sentence in it is not an option.

## Acceptance criteria

- [ ] Either the iCloud items land first, or the copy stops promising what is
      not there
- [ ] No storage option's subtitle describes behaviour the build does not have
- [ ] Revisit when `0046` and `0047` close, and again when the iPhone app ships
- [ ] `Web/` says the same thing the app does — the landing page repeats the
      iCloud claim too
