---
id: 15
title: Measure the editor on a very large note
type: chore
status: backlog
milestone: v0.2
labels:
- performance
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: s
area: editor
---

`MilkyTextView.restyle` retokenizes the entire document on every keystroke, debouncing only past 20,000 characters. That threshold was chosen by guess, not measurement.

## Acceptance criteria

- [ ] Keystroke latency measured at 10k, 50k and 200k characters
- [ ] The debounce threshold set from those numbers
- [ ] If whole-document retokenizing is the bottleneck, restyle only the edited paragraph range
