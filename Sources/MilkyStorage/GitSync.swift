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
        case command(String)

        public var errorDescription: String? {
            switch self {
            case .gitUnavailable: return "Git isn't installed. Install the Xcode Command Line Tools to enable sync."
            case .notARepository: return "This vault isn't a git repository."
            case .command(let message): return message
            }
        }
    }

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

    public func initialize() throws {
        guard isAvailable else { throw SyncError.gitUnavailable }
        _ = try run(["init"])
        _ = try? run(["add", "-A"])
        _ = try? run(["commit", "-m", "Initial vault commit"])
    }

    /// Commit local edits, rebase on top of the remote, then push. Rebase (not merge)
    /// keeps a linear history, which is what you want for a notes vault.
    @discardableResult
    public func sync(message: String? = nil) throws -> Status {
        guard isAvailable else { throw SyncError.gitUnavailable }
        guard status().isRepository else { throw SyncError.notARepository }

        let dirty = ((try? run(["status", "--porcelain"])) ?? "")
        if !dirty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
