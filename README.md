# Milky

A markdown notes app for macOS that looks and behaves like Apple Notes, and stores
everything the way Obsidian does: plain `.md` files in a folder you choose.

No account. No database. No sync service of its own. Point it at a folder and that
folder is the app's entire state.

## Status

macOS app is working. iPhone app is not built yet — `MilkyCore` and `MilkyStorage`
are deliberately free of AppKit so they can be shared with it.

## Running it

```bash
./Scripts/bundle.sh          # builds build/Milky.app
open build/Milky.app
swift run milky-tests        # the test suite
./Scripts/make-icon.sh       # regenerate Milky.icns from Resources/icon.html
```

To build a disk image:

```bash
export CODESIGN_IDENTITY="Developer ID Application: … (TEAMID)"
NOTARY_PROFILE=milky ./Scripts/release.sh      # → release/Milky-<version>.dmg
./Scripts/release.sh --allow-unsigned          # local-only, Gatekeeper will refuse it
```

Version, bundle id and deployment target live in `Scripts/version.sh`.

Requires the Swift toolchain. Full Xcode is **not** needed — the app builds with
SwiftPM against the Command Line Tools SDK and is bundled into a `.app` by
`Scripts/bundle.sh`.

## Roadmap

Tracked with [cairn](https://github.com/oddurs/astralia): every item is a Markdown
file under `cairn/items`, and `ROADMAP.md` is generated from them.

```sh
cairn next          # what is ready to start
cairn board         # kanban by status
cairn roadmap       # milestones with progress
cairn render        # regenerate ROADMAP.md
```

Don't hand-edit `ROADMAP.md` — change the items and re-render.

## Landing page

`Web/` is an Astro site — one page, no dependencies beyond Astro, no webfonts.

```bash
cd Web
npm install
npm run dev        # http://localhost:4321
npm run build      # → Web/dist/index.html
npm run artifact   # also emits dist/artifact.html
```

The app window in the hero is real DOM rather than a screenshot: it stays crisp at
any resolution, follows the reader's light or dark theme, and shows the sidebar
that an in-process screen capture cannot render.

`build.inlineStylesheets: 'always'` plus `is:inline` on both scripts keeps
`dist/index.html` a single self-contained file. `npm run artifact` reshapes that
same build into body-only form for publishing as an Artifact, and fails loudly if
anything external sneaks in.

Both **Download for Mac** buttons currently point at `#` — wire them to a release
once there is one.

## Storage

Every option is the same mechanism — a directory — which is why none of them ask
you to log in:

| Choice | What it actually is |
|---|---|
| On My Mac | any local folder |
| iCloud Drive | a folder under `~/Library/Mobile Documents`, synced by the OS |
| Dropbox | a folder under `~/Dropbox`, synced by Dropbox |
| Git repository | a folder that happens to be a git clone |

Git sync shells out to the system `git`, so it reuses your existing SSH agent,
credential helper, and config. `Sync Now` (⌘S) commits everything, rebases on the
remote, and pushes. An FSEvents watcher picks up changes made by a sync daemon,
another device, or another editor.

## The editor

There is no preview pane. The markdown source *is* the rendered document: syntax
characters stay in the file but fade back until your cursor enters the line, so
what you see is always what's on disk.

- Bullets and checkboxes are **drawn** over the hidden `-` and `[x]` — the file
  keeps its plain text
- Code blocks, quotes, tags, and inline code get real rounded backgrounds, drawn
  by the text view rather than faked with square background attributes
- Return continues a list; Return on an empty item ends it
- `[[Wiki links]]` navigate, and create the note if it doesn't exist
- `#tags` are collected into the sidebar
- ⌘B, ⌘I, ⌘E, ⌘⇧U for emphasis; ⌃⌘1/2 headings; ⌘⇧8 bullets; ⌘⇧L checklist

The filename is the note's title. Renaming the title in the editor renames the
file, which keeps the model honest: there is no hidden metadata anywhere.

## Layout

```
Sources/
  MilkyCore/      note model + markdown tokenizer   (no UI, no AppKit)
  MilkyStorage/   vault, file watcher, git sync     (no UI, no AppKit)
  MilkyUI/        SwiftUI views + the AppKit editor (macOS today, iOS later)
  MilkyMac/       app entry point and menu bar
  MilkyTests/     assertion suite (see Testing below)
```

## Testing

Neither Swift Testing nor XCTest is usable on a machine with only the Command Line
Tools installed — the bundled `Testing.framework` is missing `lib_TestingInterop.dylib`
and there is no `XCTest.framework` at all. The suite therefore runs as a plain
executable with a small assertion harness:

```bash
swift run milky-tests
MILKY_TEST_TRACE=1 swift run milky-tests   # print each suite as it starts
```

It covers the tokenizer, the note model, vault file operations, and git sync
end-to-end against a real local remote. If you install Xcode, this is worth
converting to a proper test target.

## Development helpers

The macOS binary accepts a few flags used for design review:

```bash
./build/Milky.app/Contents/MacOS/Milky \
  --vault ~/Notes --appearance light \
  --snapshot /tmp/shot.png --delay 4 --quit-after-snapshot
```

`--snapshot` renders the window from inside the process, so it works without
granting Screen Recording. It cannot capture Liquid Glass materials, so the
sidebar shows up blank in these captures — that is a limitation of the capture,
not of the app.
