import Foundation

/// What a span of code means. Deliberately small: seven roles a reader can tell
/// apart at a glance, rather than the thirty a full grammar would produce and
/// which no colour scheme can keep distinct.
public enum CodeToken: String, Equatable, Sendable, CaseIterable {
    case keyword
    case string
    case number
    case type
    case function
    case comment
    case punctuation
}

public struct CodeSpan: Equatable, Sendable {
    public var range: NSRange
    public var token: CodeToken

    public init(_ range: NSRange, _ token: CodeToken) {
        self.range = range
        self.token = token
    }
}

/// A lexer, not a parser. It recognises the shapes that carry meaning when you
/// are *reading* a snippet — comments, strings, numbers, declarations, type and
/// call names — and leaves everything else as plain text.
///
/// This is an honest limit, not a stopgap: notes hold fragments far more often
/// than compilable files, and a real grammar would reject half of them.
/// Languages it does not know still get comments, strings and numbers, which is
/// most of the value.
public enum CodeHighlighter {

    // MARK: - Languages

    public struct Language: Sendable {
        var keywords: Set<String>
        var lineComment: [String]
        var blockComment: (open: String, close: String)?
        /// Languages where `#` opens a comment rather than a preprocessor directive.
        var hashComments: Bool
        /// Whether capitalised identifiers should be read as type names.
        var capitalisedAreTypes: Bool

        init(keywords: Set<String>,
             lineComment: [String] = ["//"],
             blockComment: (open: String, close: String)? = ("/*", "*/"),
             hashComments: Bool = false,
             capitalisedAreTypes: Bool = true) {
            self.keywords = keywords
            self.lineComment = lineComment
            self.blockComment = blockComment
            self.hashComments = hashComments
            self.capitalisedAreTypes = capitalisedAreTypes
        }
    }

    /// Resolves a fence's info string. `swift`, `SWIFT`, `swift title="x"` and
    /// `js` all land somewhere sensible; an unknown language gets the generic
    /// lexer rather than nothing.
    public static func language(for info: String?) -> Language {
        guard let raw = info?
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ").first?
            .lowercased(), !raw.isEmpty
        else { return generic }

        switch raw {
        case "swift": return swift
        case "js", "jsx", "javascript", "mjs", "cjs": return javascript
        case "ts", "tsx", "typescript": return typescript
        case "json", "jsonc": return json
        case "sh", "bash", "zsh", "shell", "console": return shell
        case "py", "python": return python
        case "rs", "rust": return rust
        case "go", "golang": return go
        case "css", "scss": return css
        case "html", "xml", "svg": return markup
        case "c", "h", "cpp", "cc", "hpp", "objc", "m", "java", "kt", "kotlin", "cs": return cLike
        case "yml", "yaml", "toml", "ini": return config
        default: return generic
        }
    }

    static let swift = Language(keywords: [
        "actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch", "class",
        "continue", "default", "defer", "deinit", "do", "else", "enum", "extension", "fallthrough",
        "false", "fileprivate", "final", "for", "func", "guard", "if", "import", "in", "indirect",
        "init", "inout", "internal", "is", "lazy", "let", "mutating", "nil", "nonisolated", "open",
        "operator", "private", "protocol", "public", "repeat", "required", "rethrows", "return",
        "self", "Self", "some", "static", "struct", "subscript", "super", "switch", "throw", "throws",
        "true", "try", "typealias", "var", "weak", "where", "while", "yield",
    ])

    static let javascript = Language(keywords: [
        "async", "await", "break", "case", "catch", "class", "const", "continue", "debugger",
        "default", "delete", "do", "else", "export", "extends", "false", "finally", "for", "from",
        "function", "get", "if", "import", "in", "instanceof", "let", "new", "null", "of", "return",
        "set", "static", "super", "switch", "this", "throw", "true", "try", "typeof", "undefined",
        "var", "void", "while", "yield",
    ])

    static let typescript = Language(keywords: javascript.keywords.union([
        "abstract", "any", "as", "boolean", "declare", "enum", "implements", "interface", "keyof",
        "namespace", "never", "number", "private", "protected", "public", "readonly", "satisfies",
        "string", "type", "unknown",
    ]))

    static let json = Language(
        keywords: ["true", "false", "null"],
        lineComment: [], blockComment: nil, capitalisedAreTypes: false)

    static let shell = Language(
        keywords: ["case", "do", "done", "elif", "else", "esac", "exit", "export", "fi", "for",
                   "function", "if", "in", "local", "return", "set", "then", "until", "while"],
        lineComment: [], blockComment: nil, hashComments: true, capitalisedAreTypes: false)

    static let python = Language(
        keywords: ["and", "as", "assert", "async", "await", "break", "class", "continue", "def",
                   "del", "elif", "else", "except", "False", "finally", "for", "from", "global",
                   "if", "import", "in", "is", "lambda", "None", "nonlocal", "not", "or", "pass",
                   "raise", "return", "True", "try", "while", "with", "yield"],
        lineComment: [], blockComment: nil, hashComments: true)

    static let rust = Language(keywords: [
        "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum",
        "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move",
        "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait", "true",
        "type", "unsafe", "use", "where", "while",
    ])

    static let go = Language(keywords: [
        "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough",
        "for", "func", "go", "goto", "if", "import", "interface", "map", "nil", "package", "range",
        "return", "select", "struct", "switch", "true", "false", "type", "var",
    ])

    static let cLike = Language(keywords: [
        "auto", "bool", "break", "case", "catch", "char", "class", "const", "continue", "default",
        "delete", "do", "double", "else", "enum", "extends", "extern", "false", "final", "float",
        "for", "goto", "if", "implements", "import", "inline", "int", "interface", "long",
        "namespace", "new", "nullptr", "package", "private", "protected", "public", "return",
        "short", "sizeof", "static", "struct", "switch", "template", "this", "throw", "true", "try",
        "typedef", "typename", "union", "unsigned", "using", "virtual", "void", "while",
    ])

    static let css = Language(
        keywords: ["and", "from", "important", "not", "to"],
        lineComment: [], capitalisedAreTypes: false)

    static let markup = Language(
        keywords: [], lineComment: [], blockComment: ("<!--", "-->"), capitalisedAreTypes: false)

    static let config = Language(
        keywords: ["false", "no", "null", "true", "yes"],
        lineComment: [], blockComment: nil, hashComments: true, capitalisedAreTypes: false)

    /// For fences with no language, or one we don't know. Comments, strings and
    /// numbers are nearly universal, so this is useful rather than a stub.
    static let generic = Language(
        keywords: [], lineComment: ["//"], blockComment: ("/*", "*/"), hashComments: true,
        capitalisedAreTypes: false)

    // MARK: - Lexing

    private static let cache = RegexCache()

    /// Spans are non-overlapping and in source order.
    public static func spans(in code: String, language: Language) -> [CodeSpan] {
        let ns = code as NSString
        var spans: [CodeSpan] = []
        var claimed = IndexSet()

        func claim(_ range: NSRange) -> Bool {
            guard range.length > 0 else { return false }
            let set = IndexSet(integersIn: range.location ..< NSMaxRange(range))
            guard claimed.intersection(set).isEmpty else { return false }
            claimed.formUnion(set)
            return true
        }

        func scan(_ pattern: String, _ token: CodeToken) {
            for match in cache.matches(pattern, in: code) where claim(match.range) {
                spans.append(CodeSpan(match.range, token))
            }
        }

        // Order is the whole algorithm: comments and strings swallow their
        // contents, so they must claim their ranges before anything inside them
        // can be mistaken for a keyword.
        if let block = language.blockComment {
            let open = NSRegularExpression.escapedPattern(for: block.open)
            let close = NSRegularExpression.escapedPattern(for: block.close)
            scan("\(open)[\\s\\S]*?(\(close)|$)", .comment)
        }
        for marker in language.lineComment {
            scan("\(NSRegularExpression.escapedPattern(for: marker)).*", .comment)
        }
        if language.hashComments {
            // Not a shebang, and not a CSS colour.
            scan("(?<![\\w#])#(?![0-9a-fA-F]{3,8}\\b).*", .comment)
        }

        scan("\"\"\"[\\s\\S]*?\"\"\"", .string)      // Swift and Python multi-line
        scan("\"(\\\\.|[^\"\\\\\\n])*\"", .string)
        scan("'(\\\\.|[^'\\\\\\n])*'", .string)
        scan("`(\\\\.|[^`\\\\])*`", .string)          // template literals

        scan("\\b0[xX][0-9a-fA-F_]+\\b", .number)
        scan("\\b\\d[\\d_]*(\\.\\d+)?([eE][-+]?\\d+)?\\b", .number)

        if !language.keywords.isEmpty {
            let alternatives = language.keywords
                .sorted { $0.count > $1.count }
                .map { NSRegularExpression.escapedPattern(for: $0) }
                .joined(separator: "|")
            scan("(?<![\\w.$])(\(alternatives))(?![\\w$])", .keyword)
        }

        // A name immediately followed by '(' is being called or declared.
        for match in cache.matches("\\b([A-Za-z_][\\w]*)\\s*(?=\\()", in: code) {
            let name = match.range(at: 1)
            guard !language.keywords.contains(ns.substring(with: name)) else { continue }
            if claim(name) { spans.append(CodeSpan(name, .function)) }
        }

        if language.capitalisedAreTypes {
            scan("\\b[A-Z][A-Za-z0-9_]*\\b", .type)
        }

        scan("[{}()\\[\\];,.:<>=+\\-*/%!&|^~?]+", .punctuation)

        return spans.sorted { $0.range.location < $1.range.location }
    }

    public static func spans(in code: String, info: String?) -> [CodeSpan] {
        spans(in: code, language: language(for: info))
    }
}
