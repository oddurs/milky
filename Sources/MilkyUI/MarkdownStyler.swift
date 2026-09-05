#if canImport(AppKit)
import AppKit
import CoreText
import MilkyCore

/// Block backgrounds and rules that can't be expressed as text attributes —
/// the text view draws these behind the glyphs.
public enum BlockDecoration: Equatable {
    case codeBlock(NSRange)
    case quote(NSRange)
    case rule(NSRange)
    /// Inline code and tags, drawn as rounded pills — a text background attribute
    /// can only give square corners.
    case pill(NSRange, PillStyle)
    case marker(NSRange, MarkerGlyph)
    /// The bar of a radical, drawn over its radicand.
    case overline(NSRange)
}

public enum PillStyle: Equatable { case code, tag }

/// List markers are drawn rather than typed: the file keeps its `-` and `[x]`,
/// but the reader sees a bullet and a checkbox.
public enum MarkerGlyph: Equatable { case bullet, checkboxOpen, checkboxDone }

/// Applies live formatting directly to the editor's storage. There is no separate
/// preview mode: the markdown *is* the rendered document, with its punctuation
/// dimmed until the caret enters the line.
public enum MarkdownStyler {

    public struct Output {
        public var decorations: [BlockDecoration]
        public var links: [(NSRange, String, TokenKind)]
        /// Character index → the glyph to draw there, or nil to draw nothing.
        /// The text view hands this to its layout manager, which is what lets
        /// `\alpha` display as `α` while the file still says `\alpha`.
        public var mathGlyphs: [Int: Character?] = [:]
    }

    @discardableResult
    public static func apply(to storage: NSTextStorage,
                             theme: Theme,
                             activeParagraph: NSRange?) -> Output {
        let text = storage.string
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        let tokens = MarkdownSyntax.tokenize(text)

        storage.beginEditing()
        defer { storage.endEditing() }

        storage.setAttributes(baseAttributes(theme), range: full)

        // Index block-level tokens by paragraph so each line can be styled as a unit.
        var blockKindByLocation: [Int: TokenKind] = [:]
        for token in tokens {
            switch token.kind {
            case .heading, .codeBlock, .codeFence, .blockquote, .listBullet,
                 .listNumber, .taskOpen, .taskDone, .horizontalRule, .frontmatter,
                 .tableCell, .tablePipe, .tableDelimiter:
                let paragraph = ns.paragraphRange(for: NSRange(location: min(token.range.location, max(ns.length - 1, 0)), length: 0))
                if blockKindByLocation[paragraph.location] == nil {
                    blockKindByLocation[paragraph.location] = token.kind
                }
            default: break
            }
        }

        var decorations: [BlockDecoration] = []
        var codeRunStart: Int? = nil
        var codeRunEnd: Int = 0

        // Same bound as the tokenizer: paragraphRange(for:) at the end of the string
        // reports the last paragraph, so the loop must stop before `length`.
        var location = 0
        while location < ns.length {
            let paragraph = ns.paragraphRange(for: NSRange(location: location, length: 0))
            let kind = blockKindByLocation[paragraph.location]
            let isBlank = ns.substring(with: paragraph).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            applyBlock(kind, to: storage, paragraph: paragraph, theme: theme, isBlank: isBlank)

            let isCode = kind == .codeBlock || kind == .codeFence
            if isCode {
                if codeRunStart == nil { codeRunStart = paragraph.location }
                codeRunEnd = NSMaxRange(paragraph)
            } else if let start = codeRunStart {
                decorations.append(.codeBlock(NSRange(location: start, length: codeRunEnd - start)))
                codeRunStart = nil
            }
            if kind == .blockquote { decorations.append(.quote(paragraph)) }
            if kind == .horizontalRule { decorations.append(.rule(paragraph)) }

            location = NSMaxRange(paragraph)
        }
        if let start = codeRunStart {
            decorations.append(.codeBlock(NSRange(location: start, length: codeRunEnd - start)))
        }

        var links: [(NSRange, String, TokenKind)] = []
        for token in tokens {
            guard NSMaxRange(token.range) <= ns.length, token.range.length > 0 else { continue }
            if let glyph = applyInline(token, to: storage, theme: theme,
                                       activeParagraph: activeParagraph, ns: ns) {
                decorations.append(glyph)
            }
            if token.role == .content {
                if token.kind == .inlineCode { decorations.append(.pill(token.range, .code)) }
                if token.kind == .tag { decorations.append(.pill(token.range, .tag)) }
            }
            if let payload = token.payload, token.role == .content,
               token.kind == .link || token.kind == .wikiLink || token.kind == .tag {
                links.append((token.range, payload, token.kind))
            }
        }

        applySyntaxHighlighting(tokens, to: storage, theme: theme, ns: ns)
        let math = applyMath(tokens, to: storage, theme: theme,
                             activeParagraph: activeParagraph, ns: ns,
                             decorations: &decorations)

        return Output(decorations: decorations, links: links, mathGlyphs: math)
    }

    // MARK: - Math

    /// Typesets `$…$` and `$$…$$`.
    ///
    /// The caret's own line is left as source — the same reveal every other
    /// construct uses — so you always have a way to see and edit what you wrote.
    private static func applyMath(_ tokens: [Token], to storage: NSTextStorage, theme: Theme,
                                  activeParagraph: NSRange?, ns: NSString,
                                  decorations: inout [BlockDecoration]) -> [Int: Character?] {
        var glyphs: [Int: Character?] = [:]

        for token in tokens where token.role == .content
            && (token.kind == .mathInline || token.kind == .mathBlock) {
            let range = token.range
            guard range.length > 0, NSMaxRange(range) <= ns.length else { continue }

            let isActive = activeParagraph.map { NSIntersectionRange($0, range).length > 0 } ?? false
            let source = ns.substring(with: range)
            let rendered = MathRenderer.render(source)

            // Character offsets only line up when the source is all BMP; a stray
            // emoji inside math would desynchronise them, so bail rather than
            // mis-position every glyph after it.
            guard rendered.count == source.count, source.utf16.count == source.count else { continue }

            // If any symbol in this span cannot be drawn, the span keeps its
            // source rather than hiding the letters around a glyph that never
            // appears — which is how `\in` ended up rendering as a lone
            // backslash.
            var fonts = [Int: NSFont]()
            var renderable = true
            for (offset, item) in rendered.enumerated() {
                let size = theme.bodySize * scale(for: item.style.scriptDepth)
                let base = theme.mathFont(size: size, italic: item.style.italic)
                fonts[offset] = base
                guard let display = item.display, !display.isASCII else { continue }
                let sourceCharacter = Array(source)[offset]
                guard let usable = renderableFont(for: display, source: sourceCharacter, base: base) else {
                    renderable = false
                    break
                }
                fonts[offset] = usable
            }

            for (offset, item) in rendered.enumerated() {
                let index = range.location + offset
                let charRange = NSRange(location: index, length: 1)
                let size = theme.bodySize * scale(for: item.style.scriptDepth)

                storage.addAttribute(.font,
                                     value: fonts[offset] ?? theme.mathFont(size: size, italic: item.style.italic),
                                     range: charRange)
                storage.addAttribute(.foregroundColor, value: Ink.ink, range: charRange)

                switch item.style.raise {
                case .superscript:
                    storage.addAttribute(.baselineOffset, value: theme.bodySize * 0.36, range: charRange)
                case .subscript:
                    storage.addAttribute(.baselineOffset, value: -theme.bodySize * 0.14, range: charRange)
                case .none:
                    break
                }

                if !isActive, renderable {
                    glyphs[index] = item.display
                }
            }

            // One bar per radical, not one per character: a decoration per glyph
            // draws a dashed line with a gap at every letter boundary.
            var runStart: Int? = nil
            for (offset, item) in rendered.enumerated() {
                let overlined = item.style.overline
                if overlined, runStart == nil { runStart = offset }
                if !overlined, let start = runStart {
                    decorations.append(.overline(NSRange(location: range.location + start,
                                                         length: offset - start)))
                    runStart = nil
                }
            }
            if let start = runStart {
                decorations.append(.overline(NSRange(location: range.location + start,
                                                     length: rendered.count - start)))
            }
        }
        return glyphs
    }

    /// The serif face does not carry every symbol, so each substitution needs a
    /// font that demonstrably has the glyph. Asking the font is the only reliable
    /// test — a cascade will happily claim coverage it cannot draw.
    /// The font has to cover the replacement *and* the character it stands in
    /// for. AppKit resolves font substitution before the glyph delegate runs, so
    /// a font that draws ∈ but not the backslash it replaces gets swapped out
    /// underneath us — and the substitution silently never happens.
    static func renderableFont(for character: Character, source: Character, base: NSFont) -> NSFont? {
        func canDraw(_ font: NSFont, _ c: Character) -> Bool {
            let utf16 = Array(String(c).utf16)
            guard utf16.count == 1 else { return false }
            var unit = utf16[0]
            var glyph: CGGlyph = 0
            return CTFontGetGlyphsForCharacters(font, &unit, &glyph, 1) && glyph != 0
        }
        func usable(_ font: NSFont) -> Bool { canDraw(font, character) && canDraw(font, source) }

        if usable(base) { return base }

        let text = String(character) as NSString
        let cascaded = CTFontCreateForString(base, text as CFString,
                                             CFRange(location: 0, length: text.length)) as NSFont
        if usable(cascaded) { return cascaded }

        // The system face carries far more of the maths block than the serif does.
        for candidate in [NSFont.systemFont(ofSize: base.pointSize),
                          NSFont(name: "Apple Symbols", size: base.pointSize),
                          NSFont(name: "STIXTwoMath-Regular", size: base.pointSize)] {
            if let candidate, usable(candidate) { return candidate }
        }
        return nil
    }

    /// Scripts shrink, but never below legibility.
    private static func scale(for depth: Int) -> CGFloat {
        switch depth {
        case 0: return 1.0
        case 1: return 0.74
        default: return 0.6
        }
    }

    // MARK: - Code

    /// Colour inside fenced blocks, run after the markdown pass so it overwrites
    /// the flat code colour.
    ///
    /// Highlighting works on a whole block rather than line by line: a multi-line
    /// string or block comment only reads correctly with its neighbours present.
    private static func applySyntaxHighlighting(_ tokens: [Token], to storage: NSTextStorage,
                                                theme: Theme, ns: NSString) {
        var blocks: [(range: NSRange, language: String?)] = []
        for token in tokens where token.kind == .codeBlock {
            guard NSMaxRange(token.range) <= ns.length else { continue }
            // Lines are contiguous when only a newline separates them.
            if var last = blocks.last,
               token.range.location <= NSMaxRange(last.range) + 1,
               last.language == token.payload {
                last.range = NSUnionRange(last.range, token.range)
                blocks[blocks.count - 1] = last
            } else {
                blocks.append((token.range, token.payload))
            }
        }

        for block in blocks {
            guard block.range.length > 0 else { continue }
            let code = ns.substring(with: block.range)
            for span in CodeHighlighter.spans(in: code, info: block.language) {
                let range = NSRange(location: block.range.location + span.range.location,
                                    length: span.range.length)
                guard NSMaxRange(range) <= ns.length else { continue }
                storage.addAttribute(.foregroundColor, value: colour(for: span.token), range: range)
                if span.token == .comment {
                    storage.addAttribute(.font,
                                         value: theme.monoFont(size: theme.bodySize * 0.93, italic: true),
                                         range: range)
                }
                if span.token == .function {
                    storage.addAttribute(.font,
                                         value: theme.monoFont(size: theme.bodySize * 0.93, weight: .semibold),
                                         range: range)
                }
            }
        }
    }

    /// Seven roles, three hues and the neutrals. Keyword carries the brand; the
    /// rest sit far enough apart in hue to stay distinct at 13pt.
    private static func colour(for token: CodeToken) -> NSColor {
        switch token {
        case .keyword:     return Ink.codeKeyword
        case .string:      return Ink.codeString
        case .number:      return Ink.codeNumber
        case .type:        return Ink.codeType
        case .comment:     return Ink.codeComment
        case .punctuation: return Ink.codePunctuation
        case .function:    return Ink.ink
        }
    }

    // MARK: - Base

    static func baseAttributes(_ theme: Theme) -> [NSAttributedString.Key: Any] {
        [.font: theme.bodyFont,
         .foregroundColor: Ink.ink,
         .paragraphStyle: bodyParagraphStyle(theme)]
    }

    static func bodyParagraphStyle(_ theme: Theme) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = theme.lineHeightMultiple
        return style
    }

    // MARK: - Block styling

    private static func applyBlock(_ kind: TokenKind?, to storage: NSTextStorage,
                                   paragraph: NSRange, theme: Theme, isBlank: Bool) {
        guard paragraph.length > 0 else { return }
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = theme.lineHeightMultiple
        // Markdown source is usually hard-wrapped, so consecutive non-empty lines are
        // one paragraph. Spacing therefore comes from the blank line between blocks,
        // set compact here so the gap reads as a paragraph break, not a dropped line.
        style.paragraphSpacing = 0

        if isBlank {
            style.lineHeightMultiple = theme.blankLineHeightMultiple
            storage.addAttribute(.paragraphStyle, value: style, range: paragraph)
            return
        }

        switch kind {
        case .heading(let level):
            let size = theme.headingSize(level)
            style.paragraphSpacingBefore = theme.headingSpacingBefore(level)
            style.lineHeightMultiple = 1.18
            storage.addAttribute(.font,
                                 value: theme.font(size: size, weight: theme.headingWeight(level)),
                                 range: paragraph)
            // Big display type needs its tracking pulled in to look drawn, not stretched.
            if level <= 2 {
                storage.addAttribute(.kern, value: -size * 0.014, range: paragraph)
            }

        case .codeBlock, .codeFence:
            style.lineHeightMultiple = 1.25
            style.firstLineHeadIndent = 12
            style.headIndent = 12
            storage.addAttribute(.font, value: theme.monoFont(), range: paragraph)
            storage.addAttribute(.foregroundColor, value: Ink.ink, range: paragraph)

        case .blockquote:
            style.firstLineHeadIndent = 18
            style.headIndent = 18
            storage.addAttribute(.foregroundColor, value: Ink.inkSoft, range: paragraph)
            storage.addAttribute(.font,
                                 value: theme.font(size: theme.bodySize, italic: theme.typeface != .mono),
                                 range: paragraph)

        case .listBullet, .listNumber, .taskOpen, .taskDone:
            // Hanging indent so wrapped list lines align under the text, not the bullet.
            let indent = theme.bodySize * 1.5
            style.firstLineHeadIndent = 0
            style.headIndent = indent
            // Strikethrough is applied to the task's text only, in applyInline —
            // dragging it across the checkbox looks like a mistake.

        case .horizontalRule:
            storage.addAttribute(.foregroundColor, value: NSColor.clear, range: paragraph)

        case .tableCell, .tablePipe, .tableDelimiter:
            // A source table only lines up in a monospaced face. Setting the row
            // in mono is what makes hand-aligned columns actually align.
            style.lineHeightMultiple = 1.25
            storage.addAttribute(.font, value: theme.monoFont(size: theme.bodySize * 0.92), range: paragraph)

        case .frontmatter:
            storage.addAttribute(.font, value: theme.monoFont(size: theme.bodySize * 0.82), range: paragraph)
            storage.addAttribute(.foregroundColor, value: Ink.inkSoft, range: paragraph)
            style.lineHeightMultiple = 1.1

        default:
            break
        }

        storage.addAttribute(.paragraphStyle, value: style, range: paragraph)
    }

    // MARK: - Inline styling

    @discardableResult
    private static func applyInline(_ token: Token, to storage: NSTextStorage, theme: Theme,
                                    activeParagraph: NSRange?, ns: NSString) -> BlockDecoration? {
        let range = token.range
        let isActive = activeParagraph.map { NSIntersectionRange($0, range).length > 0
            || ($0.location <= range.location && NSMaxRange($0) >= NSMaxRange(range)) } ?? false

        // Markers are the punctuation you shouldn't have to read. They fade back
        // everywhere except the line you're actually editing.
        if token.role == .marker {
            switch token.kind {
            case .horizontalRule, .frontmatter:
                return nil

            case .listBullet:
                // Hide the literal '-' and hand its rect to the bullet renderer.
                guard let dash = characterRange(in: range, matching: "[-*+]", ns: ns) else { return nil }
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: dash)
                return .marker(dash, .bullet)

            case .listNumber:
                storage.addAttribute(.foregroundColor, value: Ink.accentInk, range: range)
                return nil

            case .taskOpen, .taskDone:
                // The whole `- [x] ` marker is hidden and the box drawn at its start,
                // so checklists line up with plain bullets instead of looking nested.
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
                return .marker(range, token.kind == .taskDone ? .checkboxDone : .checkboxOpen)

            case .blockquote:
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
                return nil

            case .mathInline, .mathBlock:
                storage.addAttribute(.foregroundColor,
                                     value: isActive ? Ink.syntaxActive : Ink.syntax,
                                     range: range)
                return nil

            case .tablePipe, .tableDelimiter:
                storage.addAttribute(.foregroundColor, value: Ink.syntax, range: range)
                return nil

            case .hardBreak:
                // Trailing whitespace you cannot see, carrying meaning. Underline
                // it so the line break is visible in the source.
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                storage.addAttribute(.underlineColor, value: Ink.accentInk, range: range)
                return nil

            case .codeFence:
                storage.addAttribute(.foregroundColor, value: Ink.syntax, range: range)
                storage.addAttribute(.font, value: theme.monoFont(size: theme.bodySize * 0.8), range: range)
                return nil
            case .heading(let level):
                // Full-size '#' glyphs shout louder than the heading itself.
                storage.addAttribute(.font,
                                     value: theme.font(size: theme.headingSize(level) * 0.58, weight: .semibold),
                                     range: range)
                storage.addAttribute(.foregroundColor,
                                     value: isActive ? Ink.syntaxActive : Ink.syntax,
                                     range: range)
                return nil
            default:
                storage.addAttribute(.foregroundColor,
                                     value: isActive ? Ink.syntaxActive : Ink.syntax,
                                     range: range)
                return nil
            }
        }

        switch token.kind {
        case .bold:
            addTrait(.bold, to: storage, range: range, theme: theme)
        case .italic:
            addTrait(.italic, to: storage, range: range, theme: theme)
        case .boldItalic:
            addTrait(.bold, to: storage, range: range, theme: theme)
            addTrait(.italic, to: storage, range: range, theme: theme)
        case .strikethrough:
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            storage.addAttribute(.foregroundColor, value: Ink.inkSoft, range: range)
        case .inlineCode:
            storage.addAttribute(.font, value: theme.monoFont(size: theme.bodySize * 0.92), range: range)
            storage.addAttribute(.foregroundColor, value: Ink.codeInk, range: range)
        case .link:
            // Leaving the app: the system's blue is what a Mac user reads as a URL.
            storage.addAttribute(.foregroundColor, value: Ink.link, range: range)
            storage.addAttribute(.cursor, value: NSCursor.pointingHand, range: range)
        case .wikiLink:
            // Staying inside the vault: the accent distinguishes it from a URL.
            storage.addAttribute(.foregroundColor, value: Ink.accentInk, range: range)
            storage.addAttribute(.cursor, value: NSCursor.pointingHand, range: range)
        case .linkURL:
            storage.addAttribute(.foregroundColor, value: isActive ? Ink.syntaxActive : Ink.syntax, range: range)
            storage.addAttribute(.font, value: theme.monoFont(size: theme.bodySize * 0.85), range: range)
        case .tag:
            storage.addAttribute(.foregroundColor, value: Ink.tagInk, range: range)
            storage.addAttribute(.font, value: theme.font(size: theme.bodySize * 0.95, weight: .medium), range: range)
        case .tableCell(let isHeader):
            if isHeader {
                storage.addAttribute(.font,
                                     value: theme.monoFont(size: theme.bodySize * 0.92, weight: .semibold),
                                     range: range)
            }
        case .footnoteRef:
            storage.addAttribute(.foregroundColor, value: Ink.accentInk, range: range)
            storage.addAttribute(.font, value: theme.font(size: theme.bodySize * 0.78), range: range)
            storage.addAttribute(.baselineOffset, value: theme.bodySize * 0.22, range: range)
        case .footnoteDef:
            storage.addAttribute(.foregroundColor, value: Ink.accentInk, range: range)
            storage.addAttribute(.font, value: theme.font(size: theme.bodySize * 0.9, weight: .medium), range: range)
        case .taskDone:
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            storage.addAttribute(.strikethroughColor, value: Ink.inkSoft, range: range)
            storage.addAttribute(.foregroundColor, value: Ink.inkSoft, range: range)
        default:
            break
        }
        return nil
    }

    /// Locates a sub-range (the bullet character, the `[x]` box) inside a marker token.
    private static func characterRange(in range: NSRange, matching pattern: String,
                                       ns: NSString) -> NSRange? {
        let found = ns.range(of: pattern, options: .regularExpression, range: range)
        return found.location == NSNotFound ? nil : found
    }

    /// Emphasis has to compose with whatever font the block already set — a bold span
    /// inside an H2 must stay H2-sized — so traits are merged onto the existing font.
    private enum Trait { case bold, italic }

    private static func addTrait(_ trait: Trait, to storage: NSTextStorage, range: NSRange, theme: Theme) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let current = (value as? NSFont) ?? theme.bodyFont
            var descriptor = current.fontDescriptor
            var traits = descriptor.symbolicTraits
            switch trait {
            case .bold: traits.insert(.bold)
            case .italic: traits.insert(.italic)
            }
            descriptor = descriptor.withSymbolicTraits(traits)
            if let font = NSFont(descriptor: descriptor, size: current.pointSize) {
                storage.addAttribute(.font, value: font, range: subrange)
            }
        }
    }
}
#endif
