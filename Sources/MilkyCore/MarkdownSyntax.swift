import Foundation

/// What a span of text means. Drives both styling and the "reveal syntax on the
/// active line" behaviour of the live editor.
public enum TokenKind: Equatable, Sendable {
    case heading(level: Int)
    case bold
    case italic
    case boldItalic
    case strikethrough
    case inlineCode
    case codeBlock
    case codeFence
    case blockquote
    case listBullet
    case listNumber
    case taskOpen
    case taskDone
    case link
    case linkURL
    case wikiLink
    case tag
    case horizontalRule
    case frontmatter
}

/// Whether a span is punctuation the reader shouldn't have to look at
/// (`**`, `#`, `](url)`) or the content itself.
public enum TokenRole: Sendable { case marker, content }

public struct Token: Equatable, Sendable {
    public var range: NSRange
    public var kind: TokenKind
    public var role: TokenRole
    /// For links and wikilinks: the destination, so the editor can make it clickable.
    public var payload: String?

    public init(_ range: NSRange, _ kind: TokenKind, _ role: TokenRole, payload: String? = nil) {
        self.range = range
        self.kind = kind
        self.role = role
        self.payload = payload
    }
}

/// A line-oriented markdown scanner. It deliberately does not build a document
/// tree — the editor only ever needs "which spans on screen get which style",
/// and staying line-local keeps re-styling cheap while typing.
public enum MarkdownSyntax {

    private static let inlinePatterns: [(String, TokenKind)] = [
        ("(\\*\\*\\*|___)(?=\\S)(.+?)(?<=\\S)\\1", .boldItalic),
        ("(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1", .bold),
        ("(?<![\\*_\\w])(\\*|_)(?=\\S)([^\\*_]+?)(?<=\\S)\\1(?![\\*_\\w])", .italic),
        ("(~~)(?=\\S)(.+?)(?<=\\S)\\1", .strikethrough),
        ("(`+)([^`]+?)\\1", .inlineCode),
    ]

    private static let regexCache = RegexCache()

    public static func tokenize(_ text: String) -> [Token] {
        let ns = text as NSString
        var tokens: [Token] = []
        var location = 0
        var inFence = false
        var inFrontmatter = false
        var lineIndex = 0

        // Bound by `<` and advance by the line's full length: at `location == length`
        // lineRange(for:) reports the *last* line rather than an empty range, which
        // would otherwise spin forever on a file with no trailing newline.
        while location < ns.length {
            let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
            let contentRange = ns.range(of: "[^\\n\\r]*", options: .regularExpression, range: lineRange)
            let line = ns.substring(with: contentRange)
            defer {
                location = NSMaxRange(lineRange)
                lineIndex += 1
            }

            // YAML frontmatter, only when it opens the document.
            if lineIndex == 0, line.trimmingCharacters(in: .whitespaces) == "---" {
                inFrontmatter = true
                tokens.append(Token(contentRange, .frontmatter, .marker))
                continue
            }
            if inFrontmatter {
                tokens.append(Token(contentRange, .frontmatter, .marker))
                if line.trimmingCharacters(in: .whitespaces) == "---" { inFrontmatter = false }
                continue
            }

            // Fenced code blocks swallow everything until they close.
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inFence.toggle()
                tokens.append(Token(contentRange, .codeFence, .marker))
                continue
            }
            if inFence {
                tokens.append(Token(contentRange, .codeBlock, .content))
                continue
            }

            scanLine(line, at: contentRange.location, into: &tokens)
        }
        return tokens
    }

    // MARK: - Line scanning

    private static func scanLine(_ line: String, at offset: Int, into tokens: inout [Token]) {
        let ns = line as NSString
        var bodyStart = 0

        if let m = regexCache.match("^(\\s*)(#{1,6})(\\s+)(.*)$", in: line) {
            let level = m.range(at: 2).length
            let markerRange = NSRange(location: offset + m.range(at: 2).location,
                                      length: m.range(at: 2).length + m.range(at: 3).length)
            tokens.append(Token(markerRange, .heading(level: level), .marker))
            tokens.append(Token(shift(m.range(at: 4), by: offset), .heading(level: level), .content))
            scanInline(ns.substring(with: m.range(at: 4)), at: offset + m.range(at: 4).location, into: &tokens)
            return
        }

        if regexCache.match("^\\s*([-*_])(\\s*\\1){2,}\\s*$", in: line) != nil {
            tokens.append(Token(NSRange(location: offset, length: ns.length), .horizontalRule, .marker))
            return
        }

        if let m = regexCache.match("^(\\s*>\\s?)(.*)$", in: line) {
            tokens.append(Token(shift(m.range(at: 1), by: offset), .blockquote, .marker))
            tokens.append(Token(shift(m.range(at: 2), by: offset), .blockquote, .content))
            bodyStart = m.range(at: 2).location
        } else if let m = regexCache.match("^(\\s*[-*+]\\s+)(\\[([ xX])\\]\\s+)(.*)$", in: line) {
            let done = ns.substring(with: m.range(at: 3)).lowercased() == "x"
            let marker = NSRange(location: offset + m.range(at: 1).location,
                                 length: m.range(at: 1).length + m.range(at: 2).length)
            tokens.append(Token(marker, done ? .taskDone : .taskOpen, .marker))
            tokens.append(Token(shift(m.range(at: 4), by: offset), done ? .taskDone : .taskOpen, .content))
            bodyStart = m.range(at: 4).location
        } else if let m = regexCache.match("^(\\s*[-*+]\\s+)(.*)$", in: line) {
            tokens.append(Token(shift(m.range(at: 1), by: offset), .listBullet, .marker))
            bodyStart = m.range(at: 2).location
        } else if let m = regexCache.match("^(\\s*\\d+[.)]\\s+)(.*)$", in: line) {
            tokens.append(Token(shift(m.range(at: 1), by: offset), .listNumber, .marker))
            bodyStart = m.range(at: 2).location
        }

        let body = ns.substring(from: bodyStart)
        scanInline(body, at: offset + bodyStart, into: &tokens)
    }

    // MARK: - Inline scanning

    private static func scanInline(_ text: String, at offset: Int, into tokens: inout [Token]) {
        let ns = text as NSString
        var claimed = IndexSet()

        func claim(_ r: NSRange) -> Bool {
            let set = IndexSet(integersIn: r.location ..< NSMaxRange(r))
            if claimed.intersection(set).isEmpty {
                claimed.formUnion(set)
                return true
            }
            return false
        }

        // Code spans win over emphasis, so they run first and claim their range.
        for (pattern, kind) in inlinePatterns.sorted(by: { $0.1 == .inlineCode && $1.1 != .inlineCode }) {
            for m in regexCache.matches(pattern, in: text) where claim(m.range) {
                let open = m.range(at: 1)
                let inner = m.range(at: 2)
                tokens.append(Token(shift(open, by: offset), kind, .marker))
                tokens.append(Token(shift(inner, by: offset), kind, .content))
                let close = NSRange(location: NSMaxRange(inner), length: open.length)
                tokens.append(Token(shift(close, by: offset), kind, .marker))
            }
        }

        // [[Wiki Link]] and [[Target|Alias]]
        for m in regexCache.matches("\\[\\[([^\\]|]+)(\\|([^\\]]+))?\\]\\]", in: text) where claim(m.range) {
            let target = ns.substring(with: m.range(at: 1))
            let aliasRange = m.range(at: 3)
            let shown = aliasRange.location == NSNotFound ? m.range(at: 1) : aliasRange
            tokens.append(Token(NSRange(location: offset + m.range.location, length: shown.location - m.range.location),
                                .wikiLink, .marker))
            tokens.append(Token(shift(shown, by: offset), .wikiLink, .content, payload: target))
            let tailStart = NSMaxRange(shown)
            tokens.append(Token(NSRange(location: offset + tailStart, length: NSMaxRange(m.range) - tailStart),
                                .wikiLink, .marker))
        }

        // [text](url) and ![alt](src)
        for m in regexCache.matches("!?\\[([^\\]]*)\\]\\(([^)\\s]+)[^)]*\\)", in: text) where claim(m.range) {
            let label = m.range(at: 1)
            let dest = ns.substring(with: m.range(at: 2))
            tokens.append(Token(NSRange(location: offset + m.range.location, length: label.location - m.range.location),
                                .link, .marker))
            tokens.append(Token(shift(label, by: offset), .link, .content, payload: dest))
            let tailStart = NSMaxRange(label)
            tokens.append(Token(NSRange(location: offset + tailStart, length: NSMaxRange(m.range) - tailStart),
                                .linkURL, .marker, payload: dest))
        }

        // Bare URLs
        for m in regexCache.matches("(?<![(\\w])https?://[^\\s)\\]]+", in: text) where claim(m.range) {
            tokens.append(Token(shift(m.range, by: offset), .link, .content,
                                payload: ns.substring(with: m.range)))
        }

        // #tags
        for m in regexCache.matches("(?<![\\w&/#])#([A-Za-z][\\w/-]*)", in: text) where claim(m.range) {
            tokens.append(Token(shift(m.range, by: offset), .tag, .content,
                                payload: ns.substring(with: m.range(at: 1))))
        }
    }

    private static func shift(_ r: NSRange, by offset: Int) -> NSRange {
        NSRange(location: r.location + offset, length: r.length)
    }
}

/// NSRegularExpression compilation is expensive and these patterns are hot —
/// the editor re-tokenizes on every keystroke.
final class RegexCache: @unchecked Sendable {
    private var cache: [String: NSRegularExpression] = [:]
    private let lock = NSLock()

    func regex(_ pattern: String) -> NSRegularExpression {
        lock.lock(); defer { lock.unlock() }
        if let r = cache[pattern] { return r }
        let r = try! NSRegularExpression(pattern: pattern)
        cache[pattern] = r
        return r
    }

    func match(_ pattern: String, in string: String) -> NSTextCheckingResult? {
        regex(pattern).firstMatch(in: string, range: NSRange(location: 0, length: (string as NSString).length))
    }

    func matches(_ pattern: String, in string: String) -> [NSTextCheckingResult] {
        regex(pattern).matches(in: string, range: NSRange(location: 0, length: (string as NSString).length))
    }
}
