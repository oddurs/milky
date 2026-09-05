---
id: 1
title: Put the project under version control
type: chore
status: done
milestone: v0.1
assignee: Oddur Sigurdsson
labels:
- release
created: 2026-09-05
updated: 2026-09-05
priority: p0
effort: s
area: build
---

There is no git repository yet, which blocks tagging a release, running anything in CI, and dogfooding Milky's own git sync against this repo.

## Acceptance criteria

- [ ] `git init` with a first commit covering Sources, Web and cairn
- [ ] `.gitignore` excludes .build, build, Web/dist and Web/node_modules
- [ ] The vault used for manual testing stays out of the repository
