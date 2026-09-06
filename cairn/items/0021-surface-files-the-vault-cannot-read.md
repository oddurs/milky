---
id: 21
title: Surface files the vault cannot read
type: bug
status: backlog
milestone: v0.2
labels:
- reliability
created: 2026-09-05
updated: 2026-09-05
priority: p1
effort: s
area: storage
---

Milky drops files it cannot read: `Vault.scan` does `guard let text = try? String(contentsOf: url) else { continue }`, so a permission failure looks identical to an empty vault.

Hit for real during v0.1: after rebuilding, macOS TCC revoked the ad-hoc-signed app's access to ~/Documents. Directory enumeration still worked, so folders appeared in the sidebar while every note vanished and the app said "No Notes". Nothing told the user their files were unreadable rather than absent.

This gets more likely once the app ships, since ~/Documents, ~/Desktop and iCloud Drive are all TCC-protected and a first-run vault will often be in one of them.

## Acceptance criteria

- [ ] A vault whose files cannot be read reports that, rather than showing an empty list
- [ ] The message distinguishes "no notes here" from "cannot read these files"
- [ ] If the failure is a permission error, offer to reopen the folder so macOS re-prompts
- [ ] Counted and surfaced per vault, not one alert per file
