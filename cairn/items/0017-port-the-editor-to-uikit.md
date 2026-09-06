---
id: 17
title: Port the editor to UIKit
type: feature
status: backlog
milestone: v1.0
labels:
- ios
depends_on:
- 16
created: 2026-09-05
updated: 2026-09-05
priority: p0
effort: l
area: editor
---

`MilkyTextView` is an `NSTextView` subclass doing its own block drawing through TextKit 1. iOS needs the same behaviour on `UITextView`: dimmed syntax that reveals on the caret's line, drawn bullets and checkboxes, code and quote backgrounds.

`MarkdownStyler` is the part worth sharing — it is already pure attribute application over `MarkdownSyntax` tokens, but it is behind `#if canImport(AppKit)` and uses NSColor and NSFont directly.

## Acceptance criteria

- [ ] MarkdownStyler builds for both platforms behind a small colour/font abstraction
- [ ] Block decorations draw identically on iOS
- [ ] The tokenizer stays untouched — it is already platform-free
