# Milky

Apple Notes-styled markdown editor for macOS (iOS planned). Files on disk are the
only source of truth.

## Build and run

```bash
./Scripts/bundle.sh && open build/Milky.app   # build + launch
swift run milky-tests                          # test suite
swift build                                    # compile check only
```

There is **no Xcode on this machine** — only the Command Line Tools. That has two
consequences worth remembering before you reach for a familiar tool:

- `xcodebuild` does not work. The app is a SwiftPM executable that
  `Scripts/bundle.sh` wraps into a `.app` with a hand-written `Info.plist`.
- Swift Testing and XCTest are both unavailable (`Testing.framework` ships without
  `lib_TestingInterop.dylib`). `Sources/MilkyTests` is a plain executable with a
  small harness in `Harness.swift`. Add cases there, not in a `Tests/` directory.

Targets use `.swiftLanguageMode(.v5)`; the AppKit editor is delegate-heavy and
does not survive Swift 6 strict concurrency unchanged.

## Architecture

`MilkyCore` and `MilkyStorage` must stay free of AppKit and SwiftUI — the iPhone
app will share them. Platform code belongs in `MilkyUI` (guarded by
`#if canImport(AppKit)`) or `MilkyMac`.

The editor is TextKit 1 on purpose: `MilkyTextView` needs exact glyph rectangles
from `NSLayoutManager` to draw code-block backgrounds, quote bars, bullets, and
checkboxes, and TextKit 2 does not report them as reliably.

Rendering flows one way: `MarkdownSyntax.tokenize` produces `[Token]`,
`MarkdownStyler.apply` turns those into text attributes plus a list of
`BlockDecoration`s, and `MilkyTextView.drawBackground` paints the decorations.
Anything that cannot be expressed as an `NSAttributedString` attribute — rounded
corners, drawn glyphs, rules — goes through `BlockDecoration`.

## Traps that have already bitten

- `NSString.lineRange(for:)` and `paragraphRange(for:)` return the **last** line
  when asked about `location == length`, not an empty range. Line-walking loops
  must be bounded by `location < ns.length`, never by checking for a zero-length
  result — that spins forever on any file without a trailing newline.
- `NSTextView` is flipped: +y runs downward. Check any hand-drawn path.
- Don't derive the note list inside `body`. It is cached in
  `AppModel.visibleNotes` because the editor republishes `draft` on every
  keystroke, and re-filtering there would rescan every note in the vault.

## Landing page (`Web/`)

An Astro site. `npm run dev` daemonizes in Astro 7 — the foreground command exits 0
while the server keeps running; use `npx astro dev status` / `stop`, not the exit
code, to tell whether it is up.

Two traps live here, both already paid for once:

- **Astro scopes every compound in a selector.** `.ln + .ln` compiles to
  `.ln[cid] + .ln[cid]` (0,4,0) and silently outranks `.ln.h2[cid]` (0,3,0), so a
  rule that won in plain CSS loses after the port. Carry values that need to vary
  in a custom property (`--ln-gap`) rather than fighting specificity.
- **Two `auto` grid rows split leftover space.** `align-content: normal` stretched
  the app window's titlebar row, and because the titlebar has a fixed height it
  floated away from the columns. Give a fixed-height header row an explicit
  `grid-template-rows: auto 1fr`.

Serve over HTTP, not `file://`, when checking a page: Chrome sniffs UTF-8 for local
files and hid a missing `<meta charset>` that turned every em dash to mojibake the
moment a real server omitted the header.

## Design system

`DesignSystem/tokens.json` is the source of truth; `Sources/MilkyUI/DesignSystem/
Tokens.generated.swift` and `Web/src/styles/tokens.generated.css` are written from
it by `Scripts/generate-tokens.sh`. Never edit a generated file — CI runs
`--check` and will fail on drift.

Four layers, and a view should only ever need the top one: tokens → typography
primitives (`TextRole`) → components (`EmptyState`, `SidebarRow`, `CountBadge`) →
views. A raw `.system(size:)` or hex value in a view means a layer below it is
missing something; add it there.

UI type uses Apple's semantic text styles, never point sizes — that is what
carries per-platform metrics and Dynamic Type. The note's reading scale is
separate (`Theme`) and the chrome must not follow it.

## The accent is a fill, not an ink

The brand colour is **#C8FF00**. It carries 17.8:1 against black and **1.2:1
against white**, so it can front a filled row, a button or a checkbox, and it
cannot be a caret, a hairline, an icon or body text on a light ground.

Two tokens, and picking the wrong one is invisible until someone opens the app in
light mode:

- `Palette.accent` / `--accent` — fills only.
- `Palette.accentInk` / `--accent-ink` — anything thin. Dark olive (#5A7300) on
  light grounds, the pure lime on dark ones, since the contrast reverses.
- `Palette.onAccent` / `--on-accent` — text *on* a lime fill. Near-black, and it
  does not follow the appearance.

`.tint()` takes the ink variant: it colours control labels as often as fills.

When measuring contrast, resolve semi-transparent backgrounds first. A script
that treats `rgba(200,255,0,.2)` as opaque compares lime against lime and reports
a 1.06:1 failure that is not real.

## Conventions

The filename is the note title; there is no separate title field on disk. Renaming
a note renames its file. Deletes go to the Finder trash, never `unlink`.

Git sync shells out to `/usr/bin/git` with `GIT_TERMINAL_PROMPT=0` so a GUI app can
never block on a credential prompt.

<!-- cairn:begin -->
## Roadmap and issues

This project tracks its roadmap and issues with `cairn`. Every item is a Markdown file under `cairn/items`, described by the schema in `cairn.toml`.

**Do not create ad-hoc TODO, PLAN or NOTES files.** Create a cairn item instead, so the work appears on the board and in the generated roadmap.

### The loop

1. `cairn next` — what is ready to start. It excludes anything blocked by unfinished dependencies and puts work already in progress first.
2. `cairn claim <ID>` — take it before you start, so no one duplicates the work. `cairn claim --next` picks and claims the top-ranked unclaimed item in one step, and prints its body so you can begin immediately.
3. Do the work, recording what you learn: `cairn set <ID> <field>=<value>`.
4. `cairn close <ID>` when it is done, or `cairn release <ID>` to hand it back.
5. `cairn check` before you report finished. It must pass.

### Commands

```sh
cairn next --json                 # ready work, ranked
cairn claim --next                # take the next ready item
cairn search <TEXT> --json        # titles, bodies and labels
cairn list --json                 # all open items
cairn list --filter 'blocked=false,priority=p0'
cairn show <ID> --json            # one item, including its body
cairn new "<TITLE>" --type <TYPE> --milestone <MILESTONE>
cairn set <ID> status=<STATUS>    # also labels+=x, or any field below
cairn close <ID>
cairn check                       # validate; run before finishing
cairn render                      # regenerate ROADMAP.md
```

### Schema

- **Types**: `feature`, `bug`, `chore`, `docs`
- **Statuses**: `backlog` (open), `planned` (open), `doing` (active), `blocked` (active), `done` (done), `dropped` (dropped)
- **`priority`**: one of p0, p1, p2, p3 — p0 is a release blocker
- **`effort`**: one of s, m, l, xl — Rough size, not an estimate
- **`area`**: free text — Subsystem this touches
- **Milestones**: `v0.1` (due 2026-10-15), `v0.2` (due 2026-12-15), `v0.3` (due 2027-03-01), `later`
- **Saved views** (`cairn list --view NAME`): `now`, `next`, `triage`

### Rules

1. Before starting work, find or create the item and set it to an active status.
2. Use the fields above rather than inventing new ones; add new fields to `cairn.toml` first.
3. Never hand-edit the generated roadmap file — change items and run `cairn render`.
4. `cairn check` must pass before the work is considered done.

<!-- cairn:end -->
