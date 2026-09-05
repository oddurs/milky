---
id: 3
title: Sign and notarize the app for distribution
type: chore
status: blocked
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

## Blocked

`security find-identity -v -p codesigning` reports **0 valid identities** on this
machine, and `xcrun notarytool history` has no stored credentials. Both require
an Apple Developer Program membership; there is nothing to do here until that
account exists.

Demonstrated, not assumed — `spctl --assess --type execute build/Milky.app`
returns `rejected` today.

## Ready and waiting

The pipeline is written and exercised; only the credentials are missing.

- `Scripts/bundle.sh` signs with `$CODESIGN_IDENTITY` and enables the hardened
  runtime when it is set, ad-hoc otherwise
- `Scripts/release.sh` refuses to build by default rather than emitting a DMG
  that Gatekeeper will reject, submits to `notarytool` when `$NOTARY_PROFILE` is
  set, and staples both the app and the image

To finish, once enrolled:

```sh
xcrun notarytool store-credentials milky \
  --apple-id <you> --team-id <TEAMID> --password <app-specific-password>
export CODESIGN_IDENTITY="Developer ID Application: … (TEAMID)"
NOTARY_PROFILE=milky Scripts/release.sh
spctl --assess --type execute --verbose build/Milky.app   # must say: accepted
```

An unrelated consequence of shipping unsigned, found while testing: an ad-hoc
signature has no stable identity, so macOS revoked the app's TCC access to
`~/Documents` on every rebuild. Notes silently vanished from the list. Filed as
`0021`.
