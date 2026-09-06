import Foundation

/// Git sync by shelling out to the system `git`. This is deliberate: it reuses the
/// user's existing credentials, SSH agent, and config, so there is still no login
/// anywhere in the app.
public final class GitSync {
    public struct Status: Equatable, Sendable {
        public var isRepository: Bool
        public var branch: String
        public var dirtyCount: Int
        public var ahead: Int
        public var behind: Int
        public var hasRemote: Bool

        public static let none = Status(isRepository: false, branch: "", dirtyCount: 0,
                                        ahead: 0, behind: 0, hasRemote: false)
    }

    public enum SyncError: LocalizedError {
        case gitUnavailable
        case notARepository
        case missingIdentity
        case command(String)

        public var errorDescription: String? {
            switch self {
            case .gitUnavailable:
                return "Git isn't installed. Install the Xcode Command Line Tools to enable sync."
            case .notARepository:
                return "This vault isn't a git repository."
            case .missingIdentity:
                return "Git needs a name and an email address before it can record a commit."
            case .command(let message):
                return message
            }
        }

        /// What to do about it, when there is something to do.
        public var recoverySuggestion: String? {
            switch self {
            case .missingIdentity:
                return """
                    Set them once and every repository on this Mac can use them:

                        git config --global user.name "Your Name"
                        git config --global user.email you@example.com
                    """
            default: return nil
            }
        }
    }

    /// Files a vault under version control should have. Seeded on init, never
    /// rewritten — a vault that already has its own opinion keeps it.
    static let seededFiles: [(name: String, contents: String)] = [
        (".gitignore", """
            # macOS
            .DS_Store

            # Milky
            .milky/cache/
            """),
        (".gitattributes", """
            # Notes are text everywhere, whatever platform writes them.
            * text=auto eol=lf
            *.md diff=markdown
            """),
    ]

    public let root: URL
    public init(root: URL) { self.root = root }

    private static let gitPath = "/usr/bin/git"

    public var isAvailable: Bool { FileManager.default.isExecutableFile(atPath: GitSync.gitPath) }

    // MARK: - Status

    public func status() -> Status {
        guard isAvailable, (try? run(["rev-parse", "--is-inside-work-tree"])) != nil else { return .none }
        let branch = (try? run(["rev-parse", "--abbrev-ref", "HEAD"])) ?? "HEAD"
        let dirty = ((try? run(["status", "--porcelain"])) ?? "")
            .split(separator: "\n").filter { !$0.isEmpty }.count
        let hasRemote = !(((try? run(["remote"])) ?? "").isEmpty)
        var ahead = 0, behind = 0
        if hasRemote, let counts = try? run(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"]) {
            let parts = counts.split(whereSeparator: { $0 == " " || $0 == "\t" }).compactMap { Int($0) }
            if parts.count == 2 { behind = parts[0]; ahead = parts[1] }
        }
        return Status(isRepository: true, branch: branch, dirtyCount: dirty,
                      ahead: ahead, behind: behind, hasRemote: hasRemote)
    }

    // MARK: - Actions

    /// Whether git can attribute a commit. Unset on a fresh Mac, and the first
    /// sync fails with a wall of git's own prose if it is not checked first.
    public var hasIdentity: Bool {
        let name = (try? run(["config", "user.name"])) ?? ""
        let email = (try? run(["config", "user.email"])) ?? ""
        return !name.isEmpty && !email.isEmpty
    }

    public func initialize() throws {
        guard isAvailable else { throw SyncError.gitUnavailable }
        _ = try run(["init"])
        try seedFiles()
        guard hasIdentity else { throw SyncError.missingIdentity }
        _ = try? run(["add", "-A"])
        _ = try? run(["commit", "-m", "Initial vault commit"])
    }

    /// Writes `.gitignore` and `.gitattributes` if the vault has neither.
    ///
    /// Without the first, every commit carries a `.DS_Store`. Without the
    /// second, opening the vault from Windows or Linux churns line endings
    /// through every file it touches.
    @discardableResult
    public func seedFiles() throws -> [String] {
        var written: [String] = []
        for file in GitSync.seededFiles {
            let url = root.appending(path: file.name)
            guard !FileManager.default.fileExists(atPath: url.path) else { continue }
            try (file.contents + "\n").write(to: url, atomically: true, encoding: .utf8)
            written.append(file.name)
        }
        return written
    }

    /// Commit local edits, rebase on top of the remote, then push. Rebase (not merge)
    /// keeps a linear history, which is what you want for a notes vault.
    @discardableResult
    public func sync(message: String? = nil) throws -> Status {
        guard isAvailable else { throw SyncError.gitUnavailable }
        guard status().isRepository else { throw SyncError.notARepository }

        let dirty = ((try? run(["status", "--porcelain"])) ?? "")
        if !dirty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Checked before staging, so the failure names the cause instead of
            // surfacing git's "Please tell me who you are".
            guard hasIdentity else { throw SyncError.missingIdentity }
            _ = try run(["add", "-A"])
            _ = try run(["commit", "-m", message ?? GitSync.defaultMessage()])
        }

        if status().hasRemote {
            do {
                _ = try run(["pull", "--rebase", "--autostash"])
            } catch {
                _ = try? run(["rebase", "--abort"])
                throw error
            }
            _ = try run(["push"])
        }
        return status()
    }

    static func defaultMessage() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "Notes: \(formatter.string(from: Date()))"
    }

    // MARK: - Process

    @discardableResult
    private func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: GitSync.gitPath)
        process.arguments = arguments
        process.currentDirectoryURL = root
        // Never let git open an interactive credential or editor prompt from a GUI app.
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_OPTIONAL_LOCKS"] = "0"
        process.environment = env

        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()

        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stdout = String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            let stderr = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw SyncError.command(stderr.isEmpty ? stdout : stderr)
        }
        return stdout
    }
}
