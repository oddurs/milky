# Milky's design system

One source of truth, two platforms, no drift.

```
DesignSystem/tokens.json          ← edit this
        │
        ├── Sources/MilkyUI/DesignSystem/Tokens.generated.swift   (Ink, Palette, Space, Radius, Motion, Measure)
        └── Web/src/styles/tokens.generated.css                   (custom properties)
```

```sh
./Scripts/generate-tokens.sh            # write both
./Scripts/generate-tokens.sh --check    # fail if they have drifted (runs in CI)
```

Never edit a generated file. CI runs `--check` on every push, so a colour changed
in one place and not the other fails the build rather than shipping.

## Layers

The system has four, and each one exists so the layer above it never has to make
a decision it shouldn't:

| Layer | Where | What it decides |
|---|---|---|
| **Tokens** | `tokens.json` | The raw values. No opinions about where they go. |
| **Primitives** | `Typography.swift` | What text roles exist, and their font and colour. |
| **Components** | `DesignSystem/Components/` | Recurring assemblies: rows, badges, empty states. |
| **Views** | `SidebarView`, `NoteListView`, … | Layout and behaviour only. |

If a view reaches for a raw `.system(size: 13)` or a hex value, one of the three
layers below it is missing something. Add it there.

## Colour

Semantic roles, never hues. `surface`, `ink`, `inkSoft`, `rule` — not `grey200`.
Every token resolves in both appearances, so nothing at a call site branches on
the theme: an `NSColor(name:)` on Apple, a redefined custom property on the web.

**The accent has a rule of its own.** `#C8FF00` carries 17.8:1 against black and
**1.2:1 against white**. It is a fill, and using it as ink produces an invisible
caret or an invisible icon in light mode — a bug that dark-mode testing will never
show you.

| Token | Use |
|---|---|
| `accent` | Fills: a selected row, a button, a checkbox disc. |
| `accentInk` | Anything thin: text, carets, icons, list markers. Dark olive on light grounds, the lime itself on dark. |
| `onAccent` | Text *on* a fill. Near-black, and it does not follow the appearance. |

`.tint()` takes `accentInk`, because it colours control labels as often as fills.

## Typography

There are two type systems, and keeping them apart is most of why the app reads
as native rather than as a web page in a window.

**UI type** is built on Apple's semantic text styles — `.body`, `.headline`,
`.caption`. Those carry the right metrics per platform (body is 13pt on macOS and
17pt on iOS) and follow Dynamic Type for free. A table of point sizes would throw
all of that away, which is why typography is deliberately *not* in `tokens.json`.

Call sites use a role, never a font:

```swift
Text(note.title).textRole(.rowTitle)
Text(timestamp).textRole(.documentMeta)

// On a filled surface, supply the colour; the role keeps the type.
Text(note.title).textRole(.rowTitle, color: Palette.onAccent)
```

Roles: `documentTitle`, `documentMeta`, `sectionLabel`, `sidebarItem`, `rowTitle`,
`rowMeta`, `status`, `badge`, `emptyTitle`, `emptyDetail`.

**Reading type** is the note itself, and it is separate on purpose. It has an
explicit scale the reader controls (face and size), because document text is
content rather than interface. It lives in `Theme`, and the UI chrome must never
follow it — the sidebar should not grow when someone bumps their note size up.

## Spacing, radius, motion

A 4pt grid (`Space.xs` … `Space.page`), with `xxs` and `sm` for optical work
inside controls. Radii run `sm` to `xl` plus `capsule`. Motion is three durations,
all short, and every one of them must no-op under `prefers-reduced-motion`.

## Components

Extracted because they were already duplicated, not invented up front:

- **`EmptyState`** — three screens had written their own (empty vault, no search
  results, no note selected). An empty state is an instruction, not an apology.
- **`SidebarRow`** — folders, tags and All Notes each drew their own, and the
  icon colour had already diverged between them.
- **`CountBadge`** — tabular figures, so a column of counts doesn't shuffle.

## Markdown

`markdown.json` is the inventory: every construct the editor understands, what
you type, how it draws, and which token it uses. `/design` renders it. Three
statuses — `full`, `partial`, and an explicit `unsupported` list, because saying
what you *don't* do is part of a spec.

The contract:

- The source is the document. No preview mode, no second representation.
- Punctuation is dimmed, never deleted.
- Nothing rewrites the file. Bullets and checkboxes are drawn over the literal
  characters; the bytes on disk are what was typed.

GFM support covers headings, fenced code with an info string, blockquotes, all
three list kinds, task lists, pipe tables, rules, frontmatter, footnotes and hard
breaks; plus the full inline set including wiki links and tags. Setext headings,
reference links, HTML, definition lists, emoji shortcodes and math are
deliberately out — each with a reason recorded in the JSON.

## Syntax highlighting

`CodeHighlighter` lives in `MilkyCore`, so iOS gets it for free. It is a lexer,
not a parser: it finds comments, strings, numbers, keywords, type names and call
sites, and leaves the rest plain. That is a deliberate limit — notes hold
fragments far more often than compilable files, and a real grammar would reject
half of them. Unknown languages fall back to a generic lexer that still finds
comments, strings and numbers.

Seven roles, three hues and the neutrals. Keyword carries the brand; a function
is distinguished by **weight** rather than a fourth colour, which is what stops
the palette becoming a rainbow. Every role clears 4.5:1 on the code ground in
both appearances — verified, not assumed.

Ordering is the algorithm: comments and strings claim their ranges first, so a
keyword inside a string is not highlighted. There are tests for exactly that.

## Adding to the system

1. A new colour → `tokens.json`, regenerate, use it. Check both appearances.
2. A new text role → `Typography.swift`. Resist adding a size; find the Apple
   text style that means what you mean.
3. A third copy of something → make it a component. Two is a coincidence.

When you check contrast, resolve semi-transparent backgrounds first. A script
that treats `rgba(200,255,0,.2)` as opaque compares lime against lime and reports
a 1.06:1 failure that isn't real.
