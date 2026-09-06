import Foundation
import MilkyCore
import MilkyStorage

let t = Harness()

// MARK: - Tokenizer helpers

func kinds(_ text: String) -> [TokenKind] { MarkdownSyntax.tokenize(text).map(\.kind) }

func span(_ text: String, _ kind: TokenKind, _ role: TokenRole) -> String? {
    guard let token = MarkdownSyntax.tokenize(text).first(where: { $0.kind == kind && $0.role == role })
    else { return nil }
    return (text as NSString).substring(with: token.range)
}

func hasHeading(_ text: String) -> Bool {
    kinds(text).contains { if case .heading = $0 { return true }; return false }
}

// MARK: - Tokenizer

t.suite("headings") {
    t.equal(span("## Vertical rhythm", .heading(level: 2), .marker), "## ", "marker")
    t.equal(span("## Vertical rhythm", .heading(level: 2), .content), "Vertical rhythm", "content")
    t.expect(kinds("###### deep").contains(.heading(level: 6)), "six hashes is a level-6 heading")
    t.expect(!hasHeading("#tag"), "'#tag' without a space is a tag, not a heading")
    t.expect(hasHeading("  ## indented"), "leading whitespace still yields a heading")
}

t.suite("inline emphasis") {
    t.equal(span("a **bold** b", .bold, .content), "bold", "bold")
    t.equal(span("a *thin* b", .italic, .content), "thin", "italic")
    t.equal(span("a ***both*** b", .boldItalic, .content), "both", "bold italic")
    t.equal(span("a ~~gone~~ b", .strikethrough, .content), "gone", "strikethrough")
    t.equal(span("a `code` b", .inlineCode, .content), "code", "inline code")
    t.expect(span("call some_long_name here", .italic, .content) == nil,
             "underscores inside a word are not emphasis")
}

t.suite("code fences") {
    let text = "before\n```swift\n# not a heading\n**not bold**\n```\nafter"
    let all = kinds(text)
    t.expect(all.contains(.codeBlock), "fenced lines are code")
    t.expect(!all.contains(.bold), "emphasis inside a fence is not parsed")
    t.expect(!hasHeading(text), "headings inside a fence are not parsed")
}

t.suite("lists and tasks") {
    t.expect(kinds("- [ ] open").contains(.taskOpen), "unchecked task")
    t.expect(kinds("- [x] done").contains(.taskDone), "checked task")
    t.expect(kinds("- [X] done").contains(.taskDone), "uppercase X is checked")
    t.expect(kinds("- plain").contains(.listBullet), "plain bullet")
    t.expect(!kinds("- plain").contains(.taskOpen), "a plain bullet is not a task")
    t.expect(kinds("3. numbered").contains(.listNumber), "ordered list")
}

t.suite("links") {
    let tokens = MarkdownSyntax.tokenize("see [the docs](https://example.com) now")
    t.equal(tokens.first { $0.kind == .link && $0.role == .content }?.payload,
            "https://example.com", "link destination")
    t.equal(span("see [the docs](https://example.com) now", .link, .content), "the docs", "link label")

    t.equal(MarkdownSyntax.tokenize("[[Reading]]").first { $0.kind == .wikiLink && $0.role == .content }?.payload,
            "Reading", "wiki target")
    t.equal(MarkdownSyntax.tokenize("[[Reading|see this]]").first { $0.kind == .wikiLink && $0.role == .content }?.payload,
            "Reading", "aliased wiki target")
    t.equal(span("[[Reading|see this]]", .wikiLink, .content), "see this", "aliased wiki label")
    t.expect(kinds("visit https://example.com now").contains(.link), "bare URL")
}

t.suite("frontmatter and rules") {
    t.expect(kinds("---\ntitle: x\n---\nbody").contains(.frontmatter), "frontmatter at the top")
    t.expect(kinds("body\n\n---\n\nmore").contains(.horizontalRule), "'---' lower down is a rule")
}

t.suite("tags") {
    let payloads = MarkdownSyntax.tokenize("note #design and #a/b")
        .filter { $0.kind == .tag }.compactMap(\.payload).sorted()
    t.equal(payloads, ["a/b", "design"], "tag payloads")
    t.expect(!kinds("# Heading").contains(.tag), "a heading is not a tag")
}

t.suite("ranges stay in bounds") {
    let text = """
    ---
    title: Fixture
    ---
    # Heading with **bold**
    - [x] done `code` [[link]] #tag
    > quote with [a](b)
    ```
    fenced
    ```
    """
    let length = (text as NSString).length
    var valid = true
    for token in MarkdownSyntax.tokenize(text) where token.range.location < 0 || NSMaxRange(token.range) > length {
        valid = false
    }
    t.expect(valid, "every token range lies inside the document")
    t.expect(MarkdownSyntax.tokenize("").isEmpty, "an empty document yields no tokens")
    t.expect(MarkdownSyntax.tokenize("\n\n\n").allSatisfy { NSMaxRange($0.range) <= 3 },
             "a document of only newlines is safe")
}

// MARK: - Note

func fixture(_ text: String, name: String = "Example") -> Note {
    Note(url: URL(fileURLWithPath: "/tmp/\(name).md"), relativePath: "\(name).md",
         folder: "", text: text, modified: Date(), created: Date())
}

t.suite("note") {
    t.equal(fixture("# Something else").title, "Example", "title comes from the filename")
    t.equal(fixture("# Heading\n\nThe **real** line.").snippet, "Heading", "snippet uses the first prose line")
    t.equal(fixture("\n\n- a list *item*").snippet, "a list item", "snippet strips markdown")
    t.equal(fixture("```\ncode\n```\nprose").snippet, "prose", "snippet skips code blocks")
    t.equal(fixture("").snippet, "", "empty note has an empty snippet")
    t.equal(fixture("see [[One]] and [[Two|alias]]").outboundLinks, ["One", "Two"], "outbound links")
    t.equal(fixture("#alpha #beta").tags, ["alpha", "beta"], "tags")
}

// MARK: - Vault

t.suite("vault") {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "milky-tests-\(ProcessInfo.processInfo.processIdentifier)")
    try? FileManager.default.removeItem(at: root)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let vault = Vault(root: root)

    let first = try vault.createNote(title: "First Note", body: "Hello #world")
    t.equal(first.title, "First Note", "created note keeps its title")
    t.equal(first.relativePath, "First Note.md", "created note sits at the vault root")

    // A second note with the same title must not overwrite the first.
    let clash = try vault.createNote(title: "First Note", body: "other")
    t.equal(clash.title, "First Note 2", "duplicate titles are disambiguated")
    t.equal(try String(contentsOf: first.url, encoding: .utf8), "Hello #world", "the original survived")

    let nested = try vault.createNote(title: "Deep", in: "Projects/Alpha", body: "x")
    t.equal(nested.relativePath, "Projects/Alpha/Deep.md", "notes can be created in nested folders")

    vault.reload()
    t.equal(vault.notes.count, 3, "all three notes are indexed")
    t.equal(vault.folders().sorted(), ["Projects", "Projects/Alpha"], "folders are discovered recursively")

    let renamed = try vault.rename(first, to: "Renamed")
    t.equal(renamed.title, "Renamed", "rename changes the title")
    t.expect(FileManager.default.fileExists(atPath: renamed.url.path), "renamed file exists")
    t.expect(!FileManager.default.fileExists(atPath: first.url.path), "old filename is gone")

    let moved = try vault.move(renamed, toFolder: "Projects")
    t.equal(moved.folder, "Projects", "move updates the folder")
    t.equal(moved.relativePath, "Projects/Renamed.md", "move updates the relative path")

    try vault.write("edited body", to: moved.url)
    t.equal(try String(contentsOf: moved.url, encoding: .utf8), "edited body", "write persists")

    // Filenames double as titles, so only filesystem-hostile characters are replaced.
    // ':' is replaced too: the filesystem tolerates it, but Finder renders it as '/'.
    t.equal(Vault.sanitize("  Trip: Paris/Rome  "), "Trip- Paris-Rome", "sanitize replaces path-hostile characters")
    t.equal(Vault.sanitize("Meeting notes"), "Meeting notes", "ordinary titles are untouched")
    t.equal(Vault.sanitize("a\nb"), "a-b", "newlines are replaced")

    vault.reload()
    let indexed = vault.notes.first { $0.relativePath == "Projects/Renamed.md" }
    t.expect(indexed != nil, "the moved note is re-indexed at its new path")

    // A hidden directory must not be walked.
    let hidden = root.appending(path: ".git")
    try FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
    try "ignored".write(to: hidden.appending(path: "Note.md"), atomically: true, encoding: .utf8)
    vault.reload()
    t.expect(!vault.notes.contains { $0.relativePath.contains(".git") }, "the .git directory is skipped")
}

t.suite("write guard") {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "milky-guard-\(ProcessInfo.processInfo.processIdentifier)")
    try? FileManager.default.removeItem(at: root)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let vault = Vault(root: root)
    let note = try vault.createNote(title: "Guarded", body: "original")
    let stamp = Vault.modificationDate(of: note.url)
    t.expect(stamp != nil, "a written file has a modification date")

    // Unchanged on disk: the write goes through and hands back a new stamp.
    let after = try vault.write("mine", to: note.url, expecting: stamp)
    t.equal(try String(contentsOf: note.url, encoding: .utf8), "mine", "an uncontested write lands")
    t.expect(after != stamp, "the returned stamp advances")

    // Someone else writes. The editor still believes the old stamp.
    Thread.sleep(forTimeInterval: 0.02)
    try "theirs".write(to: note.url, atomically: true, encoding: .utf8)

    var refused = false
    do { _ = try vault.write("mine again", to: note.url, expecting: after) }
    catch is Vault.ConflictError { refused = true }
    t.expect(refused, "a write over a changed file is refused")
    t.equal(try String(contentsOf: note.url, encoding: .utf8), "theirs",
            "and the incoming version survives untouched")

    // Deleted underneath is a conflict too, not a silent recreate.
    let doomed = try vault.createNote(title: "Doomed", body: "x")
    let doomedStamp = Vault.modificationDate(of: doomed.url)
    try FileManager.default.removeItem(at: doomed.url)
    var refusedMissing = false
    do { _ = try vault.write("resurrect", to: doomed.url, expecting: doomedStamp) }
    catch is Vault.ConflictError { refusedMissing = true }
    t.expect(refusedMissing, "writing over a file that was deleted is refused")

    // No expectation means the caller owns the file outright.
    let free = try vault.createNote(title: "Unguarded", body: "x")
    try "forced".write(to: free.url, atomically: true, encoding: .utf8)
    _ = try vault.write("overwrite", to: free.url, expecting: nil)
    t.equal(try String(contentsOf: free.url, encoding: .utf8), "overwrite",
            "an unguarded write is unconditional")
}

t.suite("vault kinds") {
    t.equal(VaultLocations.kind(of: URL(fileURLWithPath: "/Users/x/Dropbox/Notes")), .dropbox, "dropbox path")
    t.equal(VaultLocations.kind(of: URL(fileURLWithPath:
        "/Users/x/Library/Mobile Documents/com~apple~CloudDocs/Notes")), .iCloud, "icloud path")
    t.equal(VaultLocations.kind(of: URL(fileURLWithPath: "/Users/x/Notes")), .local, "plain folder")
}

t.suite("gfm tables") {
    let table = """
    | Storage | What it is |
    | --- | :---: |
    | iCloud | A folder |
    """
    let found = kinds(table)
    t.expect(found.contains(.tableCell(isHeader: true)), "header cells are marked")
    t.expect(found.contains(.tableCell(isHeader: false)), "body cells are marked")
    t.expect(found.contains(.tableDelimiter), "the delimiter row is punctuation")
    t.expect(found.contains(.tablePipe), "pipes are punctuation")

    let cells = MarkdownSyntax.tokenize(table)
        .filter { if case .tableCell = $0.kind { return true }; return false }
        .map { (table as NSString).substring(with: $0.range) }
    t.equal(cells, ["Storage", "What it is", "iCloud", "A folder"], "cells are trimmed of padding")

    // A pipe alone is not a table — the delimiter row is what proves it.
    t.expect(!kinds("a | b\nc | d").contains(.tableDelimiter), "pipes without a delimiter row are prose")
    t.expect(!kinds("a | b\nc | d").contains(.tableCell(isHeader: true)), "prose with pipes is not a table")

    t.expect(MarkdownSyntax.isTableDelimiter("|---|:--:|---:|"), "every alignment marker parses")
    t.expect(!MarkdownSyntax.isTableDelimiter("| a | b |"), "a content row is not a delimiter")

    // Emphasis still applies inside a cell.
    t.expect(kinds("| **bold** | x |\n| --- | --- |").contains(.bold), "inline markup works inside cells")
}

t.suite("fence language") {
    let tokens = MarkdownSyntax.tokenize("```swift\nlet x = 1\n```")
    let body = tokens.first { $0.kind == .codeBlock }
    t.equal(body?.payload, "swift", "the info string reaches the code lines")
    t.equal(MarkdownSyntax.tokenize("```\nplain\n```").first { $0.kind == .codeBlock }?.payload,
            nil, "a bare fence carries no language")
    t.equal(MarkdownSyntax.tokenize("```js title=\"a\"\nx\n```").first { $0.kind == .codeBlock }?.payload,
            "js title=\"a\"", "the whole info string is preserved")
}

t.suite("hard breaks and footnotes") {
    t.expect(kinds("line one  \nline two").contains(.hardBreak), "two trailing spaces")
    t.expect(kinds("line one\\\nline two").contains(.hardBreak), "trailing backslash")
    t.expect(!kinds("line one\nline two").contains(.hardBreak), "a plain newline is not a hard break")
    t.expect(kinds("see [^1] here").contains(.footnoteRef), "footnote reference")
    t.expect(kinds("[^1]: the note").contains(.footnoteDef), "footnote definition")
}

t.suite("syntax highlighting") {
    func roles(_ code: String, _ info: String?) -> [CodeToken] {
        CodeHighlighter.spans(in: code, info: info).map(\.token)
    }
    func text(_ code: String, _ info: String?, _ token: CodeToken) -> [String] {
        let ns = code as NSString
        return CodeHighlighter.spans(in: code, info: info)
            .filter { $0.token == token }.map { ns.substring(with: $0.range) }
    }

    t.equal(text("let x = 1", "swift", .keyword), ["let"], "swift keyword")
    t.equal(text("let x = 1", "swift", .number), ["1"], "number")
    t.equal(text("let s = \"hi\"", "swift", .string), ["\"hi\""], "string")
    t.equal(text("// a note\nlet x = 1", "swift", .comment), ["// a note"], "line comment")
    t.equal(text("greet(name)", "swift", .function), ["greet"], "a name before ( is a call")
    t.equal(text("let v: Vault", "swift", .type), ["Vault"], "capitalised names are types")

    // Ordering is the whole algorithm: a keyword inside a string or comment is
    // not a keyword.
    t.expect(!roles("// let x", "swift").contains(.keyword), "keywords inside comments are not highlighted")
    t.expect(!roles("\"let x\"", "swift").contains(.keyword), "keywords inside strings are not highlighted")

    t.equal(text("# a comment\necho hi", "bash", .comment), ["# a comment"], "hash comments in shell")
    t.expect(!roles("color: #C8FF00;", "css").contains(.comment), "a css colour is not a comment")
    t.equal(text("{\"a\": true}", "json", .keyword), ["true"], "json literals")

    // An unknown language still gets the universal shapes.
    t.equal(text("x = 42 // why", "fortran", .number), ["42"], "unknown languages still find numbers")
    t.equal(text("x = 42 // why", "fortran", .comment), ["// why"], "unknown languages still find comments")
    t.expect(CodeHighlighter.spans(in: "", info: "swift").isEmpty, "empty code is safe")

    // Spans must never overlap, or attribute application double-writes.
    let sample = "func greet(_ name: String) -> Int { return 1 /* x */ }"
    var last = -1, disjoint = true
    for span in CodeHighlighter.spans(in: sample, info: "swift") {
        if span.range.location < last { disjoint = false }
        last = NSMaxRange(span.range)
    }
    t.expect(disjoint, "spans are ordered and non-overlapping")
}

t.suite("math") {
    func shown(_ src: String) -> String { MathRenderer.plainText(src) }

    // One entry per source character is the contract the editor relies on.
    for sample in ["E = mc^2", "\\alpha + \\beta", "\\frac{a}{b}", "\\sqrt{x_1}", "", "\\"] {
        t.equal(MathRenderer.render(sample).count, sample.count,
                "render is 1:1 with the source for \"\(sample)\"")
    }

    t.equal(shown("\\alpha"), "α", "a command becomes one glyph")
    t.equal(shown("\\alpha + \\beta"), "α + β", "several commands")
    t.equal(shown("x \\in \\mathbb{R}"), "x ∈ ℝ", "blackboard bold")
    t.equal(shown("\\sum_{i=1}^{n}"), "∑i=1n", "scripts keep their content")
    t.equal(shown("\\frac{a}{b}"), "a⁄b", "fractions use the fraction slash")
    t.equal(shown("\\sqrt{2}"), "√2", "radicals")
    t.equal(shown("E = mc^2"), "E = mc2", "superscript content survives")

    // Unknown commands are shown as written rather than silently swallowed.
    t.equal(shown("\\wobble"), "\\wobble", "unknown commands are left alone")

    let scripted = MathRenderer.render("x^2")
    t.equal(scripted[1].display, nil, "the caret itself is hidden")
    t.equal(scripted[2].style.raise, .superscript, "the exponent is raised")
    t.equal(scripted[2].style.scriptDepth, 1, "and shrinks one level")

    let sub = MathRenderer.render("x_i")
    t.equal(sub[2].style.raise, .subscript, "underscore lowers")

    let radical = MathRenderer.render("\\sqrt{x}")
    t.expect(radical.contains { $0.style.overline }, "the radicand is overlined")

    t.equal(MathRenderer.render("x")[0].style.italic, true, "variables are italic")
    t.equal(MathRenderer.render("2")[0].style.italic, false, "digits are upright")
    t.equal(shown("\\sin x"), "sin x", "function names are set upright")

    // Malformed input must not trap.
    for broken in ["\\frac{a", "\\sqrt{", "x^", "{{{", "}}}", "\\mathbb{"] {
        t.equal(MathRenderer.render(broken).count, broken.count, "malformed input is safe: \(broken)")
    }
}

t.suite("math in markdown") {
    t.expect(kinds("Let $x^2$ be").contains(.mathInline), "inline math")
    t.expect(kinds("$$\nE = mc^2\n$$").contains(.mathBlock), "display math")
    // A price is not an equation.
    t.expect(!kinds("It costs $5 and $10 total").contains(.mathInline), "currency is not math")
    t.expect(!kinds("$ x $").contains(.mathInline), "a space after the opener disqualifies it")

    let tokens = MarkdownSyntax.tokenize("Let $x^2$ be")
    let body = tokens.first { $0.kind == .mathInline && $0.role == .content }
    t.equal(body.map { ("Let $x^2$ be" as NSString).substring(with: $0.range) }, "x^2",
            "the delimiters are markers, the body is content")
}

t.suite("git sync") {
    let sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "milky-git-\(ProcessInfo.processInfo.processIdentifier)")
    try? FileManager.default.removeItem(at: sandbox)
    try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: sandbox) }

    let remote = sandbox.appending(path: "remote.git")
    let working = sandbox.appending(path: "vault")

    @discardableResult
    func git(_ args: [String], in directory: URL) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        // Commits must not depend on the machine's global git identity.
        env["GIT_AUTHOR_NAME"] = "Milky Tests"; env["GIT_AUTHOR_EMAIL"] = "tests@milky.local"
        env["GIT_COMMITTER_NAME"] = "Milky Tests"; env["GIT_COMMITTER_EMAIL"] = "tests@milky.local"
        process.environment = env
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    let sync = GitSync(root: working)
    guard sync.isAvailable else {
        t.expect(true, "git is unavailable on this machine; sync checks skipped")
        return
    }

    // A folder that isn't a repository reports so rather than throwing.
    try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)
    t.expect(!GitSync(root: working).status().isRepository, "a plain folder is not a repository")

    git(["init", "--bare", "-b", "main", remote.path], in: sandbox)
    git(["init", "-b", "main"], in: working)
    git(["remote", "add", "origin", remote.path], in: working)

    let vault = Vault(root: working)
    _ = try vault.createNote(title: "Synced", body: "first version")

    var status = GitSync(root: working).status()
    t.expect(status.isRepository, "the vault is now a repository")
    t.expect(status.dirtyCount > 0, "the new note shows as an uncommitted change")

    git(["add", "-A"], in: working)
    git(["commit", "-m", "seed"], in: working)
    git(["push", "-u", "origin", "main"], in: working)

    // The real path under test: edit, then sync.
    try vault.write("second version", to: working.appending(path: "Synced.md"))
    status = try GitSync(root: working).sync(message: "test sync")
    t.equal(status.dirtyCount, 0, "sync commits every local change")
    t.equal(status.ahead, 0, "sync pushes the commit to the remote")

    // Prove it truly reached the remote by cloning it fresh.
    let clone = sandbox.appending(path: "clone")
    git(["clone", remote.path, clone.path], in: sandbox)
    let round = try? String(contentsOf: clone.appending(path: "Synced.md"), encoding: .utf8)
    t.equal(round, "second version", "the edit round-trips through the remote")

    // A clean vault syncs without error and stays clean.
    let unchanged = try GitSync(root: working).sync()
    t.equal(unchanged.dirtyCount, 0, "syncing a clean vault is a no-op")
}

t.finish()
