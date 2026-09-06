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

    /// Lists the vault without opening a single file.
    ///
    /// Reading contents is what makes indexing expensive, and on a cloud folder
    /// it is worse than expensive: a Dropbox online-only or iCloud evicted file
    /// is *downloaded* by the act of reading it. Enumerating metadata touches
    /// none of that, so a vault of any size and any residency lists instantly.
    public static func metadata(root: URL) -> [Note] {
        entries(root: root).map { entry in
            Note(url: entry.url, relativePath: entry.relativePath, folder: entry.folder,
                 text: "", modified: entry.modified, created: entry.created, isLoaded: false)
        }
        .sorted { $0.modified > $1.modified }
    }

    /// Reads one note's contents. Returns nil when the file cannot be read,
    /// which the caller must not confuse with an empty note — see 0021.
    public static func loadContent(of note: Note) -> String? {
        try? String(contentsOf: note.url, encoding: .utf8)
    }

    struct Entry {
        var url: URL
        var relativePath: String
        var folder: String
        var modified: Date
        var created: Date
    }

    /// The walk both scans share, so the ignore rules cannot drift apart.
    static func entries(root: URL) -> [Entry] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .creationDateKey, .nameKey]
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: keys,
                                         options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var result: [Entry] = []
        for case let url as URL in walker {
            if Vault.ignoredDirectories.contains(url.lastPathComponent) {
                walker.skipDescendants()
                continue
            }
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true { continue }
            guard markdownExtensions.contains(url.pathExtension.lowercased()) else { continue }
            result.append(Entry(url: url,
                                relativePath: Vault.relativePath(of: url, from: root),
                                folder: Vault.folderPath(of: url, from: root),
                                modified: values?.contentModificationDate ?? .distantPast,
                                created: values?.creationDate ?? .distantPast))
        }
        return result
    }

    static func scan(root: URL) -> [Note] {
        entries(root: root).compactMap { entry in
            guard let text = try? String(contentsOf: entry.url, encoding: .utf8) else { return nil }
            return Note(url: entry.url, relativePath: entry.relativePath, folder: entry.folder,
                        text: text, modified: entry.modified, created: entry.created)
        }
    }

    public func folders() -> [String] { Vault.folderPaths(root: root) }

    /// Every subdirectory that could hold notes, as vault-relative paths.
    public static func folderPaths(root: URL) -> [String] {
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

    /// Renames a folder in place. Every note underneath moves with it, which the
    /// caller sees after the next reload — paths are derived, not stored.
    @discardableResult
    public func renameFolder(_ path: String, to newName: String) throws -> String {
        let clean = Vault.sanitize(newName)
        let current = path.split(separator: "/").last.map(String.init) ?? path
        guard !clean.isEmpty, clean != current else { return path }

        let source = root.appending(path: path)
        let parent = path.split(separator: "/").dropLast().joined(separator: "/")
        let destination = parent.isEmpty ? clean : "\(parent)/\(clean)"

        // Case-only renames need the same staging dance as notes do (0049).
        if clean.lowercased() == current.lowercased() {
            let staging = root.appending(path: parent).appending(path: ".milky-folder-\(UUID().uuidString)")
            try FileManager.default.moveItem(at: source, to: staging)
            do { try FileManager.default.moveItem(at: staging, to: root.appending(path: destination)) }
            catch {
                try? FileManager.default.moveItem(at: staging, to: source)
                throw error
            }
            return destination
        }

        let target = try uniqueFolderURL(for: destination)
        try FileManager.default.moveItem(at: source, to: target)
        return Vault.relativePath(of: target, from: root)
    }

    /// Moves a folder under another one, or to the vault root when `parent` is empty.
    @discardableResult
    public func moveFolder(_ path: String, into parent: String) throws -> String {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        let destination = parent.isEmpty ? name : "\(parent)/\(name)"
        guard destination != path else { return path }
        // Moving a folder inside itself would take the vault with it.
        guard !destination.hasPrefix(path + "/") else { throw FolderError.intoItself }

        let target = try uniqueFolderURL(for: destination)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: root.appending(path: path), to: target)
        return Vault.relativePath(of: target, from: root)
    }

    /// To the Finder trash, like notes — recoverable, not gone.
    public func deleteFolder(_ path: String) throws {
        try FileManager.default.trashItem(at: root.appending(path: path), resultingItemURL: nil)
    }

    /// How many notes a folder holds, including everything nested under it.
    public func noteCount(inFolder path: String) -> Int {
        Vault.entries(root: root).filter { $0.folder == path || $0.folder.hasPrefix(path + "/") }.count
    }

    public enum FolderError: LocalizedError {
        case intoItself
        public var errorDescription: String? { "A folder can't be moved inside itself." }
    }

    private func uniqueFolderURL(for path: String) throws -> URL {
        var candidate = root.appending(path: path)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = root.appending(path: "\(path) \(counter)")
            counter += 1
        }
        return candidate
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
