#if canImport(AppKit)
import AppKit
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
                 .listNumber, .taskOpen, .taskDone, .horizontalRule, .frontmatter:
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

        return Output(decorations: decorations, links: links)
    }

    // MARK: - Base

    static func baseAttributes(_ theme: Theme) -> [NSAttributedString.Key: Any] {
        [.font: theme.bodyFont,
         .foregroundColor: Palette.text,
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
            storage.addAttribute(.foregroundColor, value: Palette.text, range: paragraph)

        case .blockquote:
            style.firstLineHeadIndent = 18
            style.headIndent = 18
            storage.addAttribute(.foregroundColor, value: Palette.secondaryText, range: paragraph)
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

        case .frontmatter:
            storage.addAttribute(.font, value: theme.monoFont(size: theme.bodySize * 0.82), range: paragraph)
            storage.addAttribute(.foregroundColor, value: Palette.secondaryText, range: paragraph)
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
                storage.addAttribute(.foregroundColor, value: Palette.accentPlatform, range: range)
                return nil

            case .taskOpen, .taskDone:
                // The whole `- [x] ` marker is hidden and the box drawn at its start,
                // so checklists line up with plain bullets instead of looking nested.
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
                return .marker(range, token.kind == .taskDone ? .checkboxDone : .checkboxOpen)

            case .blockquote:
                storage.addAttribute(.foregroundColor, value: NSColor.clear, range: range)
                return nil

            case .codeFence:
                storage.addAttribute(.foregroundColor, value: Palette.syntax, range: range)
                storage.addAttribute(.font, value: theme.monoFont(size: theme.bodySize * 0.8), range: range)
                return nil
            case .heading(let level):
                // Full-size '#' glyphs shout louder than the heading itself.
                storage.addAttribute(.font,
                                     value: theme.font(size: theme.headingSize(level) * 0.58, weight: .semibold),
                                     range: range)
                storage.addAttribute(.foregroundColor,
                                     value: isActive ? Palette.syntaxActive : Palette.syntax,
                                     range: range)
                return nil
            default:
                storage.addAttribute(.foregroundColor,
                                     value: isActive ? Palette.syntaxActive : Palette.syntax,
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
            storage.addAttribute(.foregroundColor, value: Palette.secondaryText, range: range)
        case .inlineCode:
            storage.addAttribute(.font, value: theme.monoFont(size: theme.bodySize * 0.92), range: range)
            storage.addAttribute(.foregroundColor, value: Palette.codeText, range: range)
        case .link, .wikiLink:
            storage.addAttribute(.foregroundColor, value: Palette.link, range: range)
            storage.addAttribute(.cursor, value: NSCursor.pointingHand, range: range)
        case .linkURL:
            storage.addAttribute(.foregroundColor, value: isActive ? Palette.syntaxActive : Palette.syntax, range: range)
            storage.addAttribute(.font, value: theme.monoFont(size: theme.bodySize * 0.85), range: range)
        case .tag:
            storage.addAttribute(.foregroundColor, value: Palette.tagText, range: range)
            storage.addAttribute(.font, value: theme.font(size: theme.bodySize * 0.95, weight: .medium), range: range)
        case .taskDone:
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            storage.addAttribute(.strikethroughColor, value: Palette.secondaryText, range: range)
            storage.addAttribute(.foregroundColor, value: Palette.secondaryText, range: range)
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
