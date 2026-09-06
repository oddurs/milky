---
id: 51
title: Set a git vault up properly on init
type: chore
status: done
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

`GitSync.initialize` runs `init`, `add -A`, `commit` and nothing else, which
leaves two avoidable problems:

- No `.gitignore`, so `.DS_Store` is committed on the first commit and every one
  after it.
- No `.gitattributes`, so a vault opened from Windows or Linux churns line
  endings through every file.

And `git commit` fails outright on a machine with no `user.name` — a fresh
laptop's very first sync — surfacing raw git stderr.

## Acceptance criteria

- [ ] Seed `.gitignore` (`.DS_Store`, `.milky/cache`) and `.gitattributes` (`* text=auto eol=lf`)
- [ ] Detect a missing git identity before committing and ask for one
- [ ] Never rewrite either file if the vault already has it
