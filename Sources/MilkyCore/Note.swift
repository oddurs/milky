import Foundation

/// A single markdown file in the vault. The filename is the note's title —
/// files are the source of truth, so renaming the title renames the file.
public struct Note: Identifiable, Hashable {
    public var url: URL
    public var relativePath: String
    public var folder: String
    public var text: String
    public var modified: Date
    public var created: Date

    public var id: String { relativePath }
    public var title: String { url.deletingPathExtension().lastPathComponent }

    public init(url: URL, relativePath: String, folder: String, text: String, modified: Date, created: Date) {
        self.url = url
        self.relativePath = relativePath
        self.folder = folder
        self.text = text
        self.modified = modified
        self.created = created
    }

    /// The first line of real prose, stripped of markdown, for the note list.
    public var snippet: String {
        var inFence = false
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") || line.hasPrefix("~~~") { inFence.toggle(); continue }
            if inFence || line.isEmpty { continue }
            if line == "---" { continue }
            let plain = Note.stripMarkdown(line)
            if !plain.isEmpty { return plain }
        }
        return ""
    }

    static func stripMarkdown(_ line: String) -> String {
        var s = line
        // Leading block markers
        while let r = s.range(of: "^\\s*(#{1,6}\\s+|>\\s*|[-*+]\\s+(\\[[ xX]\\]\\s+)?|\\d+\\.\\s+)",
                             options: .regularExpression) {
            s.removeSubrange(r)
            if s == line { break }
        }
        // Unwrap emphasis rather than deleting every '*' and '_', so snake_case
        // identifiers survive into the snippet intact.
        s = s.replacingOccurrences(of: "([*_]{1,3}|~~)(\\S|\\S.*?\\S)\\1",
                                   with: "$2", options: .regularExpression)
        s = s.replacingOccurrences(of: "`+", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\[\\[([^\\]|]*\\|)?([^\\]]*)\\]\\]", with: "$2", options: .regularExpression)
        s = s.replacingOccurrences(of: "!?\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Wiki-style `[[links]]` pointing at other notes.
    public var outboundLinks: [String] {
        let re = try! NSRegularExpression(pattern: "\\[\\[([^\\]|#]+)")
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespaces)
        }
    }

    /// `#tags` used in the body, ignoring headings and code.
    public var tags: [String] {
        let re = try! NSRegularExpression(pattern: "(?<![\\w&/#])#([A-Za-z][\\w/-]*)")
        var found: [String] = []
        var inFence = false
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") { inFence.toggle(); continue }
            if inFence { continue }
            // A heading is '#' followed by whitespace; '#alpha' on its own is a tag.
            if trimmed.range(of: "^#{1,6}\\s", options: .regularExpression) != nil { continue }
            let ns = line as NSString
            for m in re.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
                found.append(ns.substring(with: m.range(at: 1)))
            }
        }
        return Array(Set(found)).sorted()
    }
}
