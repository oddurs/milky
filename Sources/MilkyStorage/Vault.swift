import Foundation
import MilkyCore

/// A vault is just a folder of markdown files. That's the whole storage model:
/// point it at ~/Notes, at an iCloud Drive folder, at a Dropbox folder, or at a
/// git clone — they are all ordinary directories, so there is nothing to log into.
public final class Vault {
    public let root: URL
    public private(set) var notes: [Note] = []

    public static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "txt"]
    /// Directories that are never part of a vault. Shared with `VaultWatcher`,
    /// which must skip the same ones — a `.git` write is not a note changing.
    public static let ignoredDirectories: Set<String> = [".git", ".obsidian", ".trash", "node_modules", ".DS_Store"]

    public init(root: URL) {
        self.root = root
    }

    // MARK: - Indexing

    @discardableResult
    public func reload() -> [Note] {
        notes = Vault.scan(root: root).sorted { $0.modified > $1.modified }
        return notes
    }

    static func scan(root: URL) -> [Note] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .creationDateKey, .nameKey]
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: keys,
                                         options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var result: [Note] = []
        for case let url as URL in walker {
            let name = url.lastPathComponent
            if Vault.ignoredDirectories.contains(name) {
                walker.skipDescendants()
                continue
            }
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true { continue }
            guard markdownExtensions.contains(url.pathExtension.lowercased()) else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            result.append(Note(url: url,
                               relativePath: Vault.relativePath(of: url, from: root),
                               folder: Vault.folderPath(of: url, from: root),
                               text: text,
                               modified: values?.contentModificationDate ?? .distantPast,
                               created: values?.creationDate ?? .distantPast))
        }
        return result
    }

    /// Every subdirectory that could hold notes, as vault-relative paths.
    public func folders() -> [String] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                                         options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var result: Set<String> = []
        for case let url as URL in walker {
            if Vault.ignoredDirectories.contains(url.lastPathComponent) {
                walker.skipDescendants()
                continue
            }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            result.insert(Vault.relativePath(of: url, from: root))
        }
        return result.sorted()
    }

    // MARK: - Mutation

    /// Refused because the file changed underneath the editor.
    public struct ConflictError: LocalizedError, Equatable {
        public let url: URL
        public var errorDescription: String? {
            "\(url.lastPathComponent) changed on disk since it was opened."
        }
    }

    /// Writes only if the file still looks the way it did when it was read.
    ///
    /// The editor cannot rely on the file watcher alone: FSEvents coalesces, can
    /// be missed, and says nothing about *which* version it saw. Comparing the
    /// modification date at the moment of writing is the check that actually
    /// holds, and it is what stops a `git pull` being overwritten by an autosave
    /// half a second later.
    @discardableResult
    public func write(_ text: String, to url: URL, expecting modified: Date?) throws -> Date {
        if let modified {
            guard let current = Vault.modificationDate(of: url) else {
                // Gone from under us: deleted or replaced while it was open.
                throw ConflictError(url: url)
            }
            guard abs(current.timeIntervalSince(modified)) < 0.001 else {
                throw ConflictError(url: url)
            }
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
        return Vault.modificationDate(of: url) ?? Date()
    }

    /// Unconditional write, for callers that own the file outright.
    public func write(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Read through `FileManager` rather than `URL.resourceValues`, which caches
    /// on the URL instance — reusing a `Note`'s URL would hand back the value
    /// from the first read and the guard would never fire.
    public static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    public func createNote(title: String, in folder: String = "", body: String = "") throws -> Note {
        let directory = folder.isEmpty ? root : root.appending(path: folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = Vault.uniqueURL(for: Vault.sanitize(title), in: directory)
        try body.write(to: url, atomically: true, encoding: .utf8)
        let now = Date()
        return Note(url: url,
                    relativePath: Vault.relativePath(of: url, from: root),
                    folder: folder,
                    text: body,
                    modified: now,
                    created: now)
    }

    /// Renaming a note is renaming its file — the filename *is* the title.
    public func rename(_ note: Note, to newTitle: String) throws -> Note {
        let clean = Vault.sanitize(newTitle)
        guard !clean.isEmpty, clean != note.title else { return note }
        let directory = note.url.deletingLastPathComponent()

        // Changing only the case is not a collision, but APFS is case-insensitive
        // by default, so `fileExists` reports the note's own file and uniqueURL
        // would hand back "Note 2". Go via a temporary name instead.
        if clean.lowercased() == note.title.lowercased() {
            let target = directory.appending(path: "\(clean).\(note.url.pathExtension)")
            let staging = directory.appending(path: ".milky-rename-\(UUID().uuidString)")
            try FileManager.default.moveItem(at: note.url, to: staging)
            do {
                try FileManager.default.moveItem(at: staging, to: target)
            } catch {
                // Never leave the note stranded under a dotfile name.
                try? FileManager.default.moveItem(at: staging, to: note.url)
                throw error
            }
            var renamed = note
            renamed.url = target
            renamed.relativePath = Vault.relativePath(of: target, from: root)
            return renamed
        }

        let target = Vault.uniqueURL(for: clean, in: directory, extension: note.url.pathExtension)
        try FileManager.default.moveItem(at: note.url, to: target)
        var moved = note
        moved.url = target
        moved.relativePath = Vault.relativePath(of: target, from: root)
        return moved
    }

    public func move(_ note: Note, toFolder folder: String) throws -> Note {
        let directory = folder.isEmpty ? root : root.appending(path: folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = Vault.uniqueURL(for: note.title, in: directory, extension: note.url.pathExtension)
        try FileManager.default.moveItem(at: note.url, to: target)
        var moved = note
        moved.url = target
        moved.relativePath = Vault.relativePath(of: target, from: root)
        moved.folder = folder
        return moved
    }

    /// Deletes to the Finder trash rather than unlinking, so it stays recoverable.
    public func delete(_ note: Note) throws {
        try FileManager.default.trashItem(at: note.url, resultingItemURL: nil)
    }

    public func createFolder(named name: String, in parent: String = "") throws -> String {
        let clean = Vault.sanitize(name)
        let path = parent.isEmpty ? clean : "\(parent)/\(clean)"
        try FileManager.default.createDirectory(at: root.appending(path: path), withIntermediateDirectories: true)
        return path
    }

    // MARK: - Paths

    static func relativePath(of url: URL, from root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return url.lastPathComponent }
        return String(path.dropFirst(rootPath.count).drop(while: { $0 == "/" }))
    }

    static func folderPath(of url: URL, from root: URL) -> String {
        let relative = relativePath(of: url, from: root)
        let parts = relative.split(separator: "/").dropLast()
        return parts.joined(separator: "/")
    }

    /// Filenames are user-visible titles, so strip only what the filesystem forbids.
    public static func sanitize(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "[/:\\n\\r]", with: "-", options: .regularExpression)
        return String(cleaned.prefix(200))
    }

    static func uniqueURL(for title: String, in directory: URL, extension ext: String = "md") -> URL {
        let base = title.isEmpty ? "Untitled" : title
        var candidate = directory.appending(path: "\(base).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appending(path: "\(base) \(counter).\(ext)")
            counter += 1
        }
        return candidate
    }
}
