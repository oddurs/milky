---
id: 52
title: Decide where per-vault settings live
type: chore
status: backlog
milestone: v0.3
labels:
- design
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: s
area: storage
---

Every preference is in global `UserDefaults`, so anything that should differ per
vault has nowhere to go: sort order (`0024`), the attachments folder (`0012`),
which extensions count as notes, sidebar expansion state.

Two options, and the choice shapes several items downstream:

- A `.milky/` directory in the vault. Travels with the folder, syncs to other
  machines, matches what `.obsidian/` does — at the cost of a non-markdown
  artifact in a folder we promise is just notes.
- `UserDefaults` keyed by the vault's bookmark. Keeps the folder pristine, but
  settings do not follow the vault to another machine.

## Acceptance criteria

- [ ] Decision recorded here with its reasoning
- [ ] If a directory: it is in the seeded `.gitignore` where it should not sync,
      and out of it where it should
- [ ] `Vault.ignoredDirectories` knows about it
- [ ] Opening a vault with no settings behaves exactly as today
