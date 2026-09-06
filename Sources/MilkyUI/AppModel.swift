import Foundation
import SwiftUI
import MilkyCore
import MilkyStorage

public enum SidebarSelection: Hashable {
    case all
    case folder(String)
    case tag(String)

    var title: String {
        switch self {
        case .all: return "All Notes"
        case .folder(let path): return path.isEmpty ? "All Notes" : (path.split(separator: "/").last.map(String.init) ?? path)
        case .tag(let tag): return "#\(tag)"
        }
    }
}

@MainActor
public final class AppModel: ObservableObject {
    // MARK: - Vault

    @Published public private(set) var vault: Vault?
    @Published public private(set) var notes: [Note] = []
    @Published public private(set) var folders: [String] = []
    @Published public private(set) var tags: [String] = []
    @Published public var vaultKind: VaultKind = .local

    // MARK: - Selection & search

    @Published public var sidebarSelection: SidebarSelection = .all { didSet { refreshVisible() } }
    @Published public var selectedNoteID: Note.ID?
    @Published public var searchText: String = "" { didSet { refreshVisible() } }

    /// The note list's contents, recomputed only when the vault, folder, or query
    /// changes. Deriving it on demand would re-scan every note on each keystroke.
    @Published public private(set) var visibleNotes: [Note] = []

    // MARK: - Editing

    /// The live editor buffer. Kept separate from the indexed note so an unsaved
    /// edit is never lost to a background reindex.
    @Published public var draft: String = ""
    @Published public private(set) var isDirty = false

    /// The note changed on disk while it was being edited. Autosaving stops
    /// until this is answered, so neither version is lost by default.
    @Published public private(set) var conflict: Conflict?

    /// What the file looked like when it was read, so a write can tell whether
    /// anyone else has touched it since.
    private var loadedModified: Date?

    public struct Conflict: Identifiable, Equatable {
        public let id = UUID()
        public var noteID: Note.ID
        public var title: String
        public var mine: String
        public var theirs: String
    }

    public enum ConflictResolution { case keepMine, takeTheirs, keepBoth }

    // MARK: - Sync

    @Published public private(set) var gitStatus: GitSync.Status = .none
    @Published public private(set) var isSyncing = false
    @Published public var errorMessage: String?

    // MARK: - Appearance

    @Published public var theme = Theme() { didSet { persistTheme() } }

    private var watcher: VaultWatcher?
    /// Bumped on every reload so a slow background pass from a closed vault
    /// cannot publish over a newer one.
    private var indexGeneration = 0
    private var saveWork: DispatchWorkItem?
    private var lastLoadedNoteID: Note.ID?

    public init() {
        restoreTheme()
        if let url = VaultBookmarks.last() { open(url) }
    }

    // MARK: - Vault lifecycle

    public func open(_ url: URL) {
        flushPendingSave()
        _ = url.startAccessingSecurityScopedResource()

        // The welcome screen offers folders that may not exist yet (iCloud/Milky).
        // Creating one is the signal that this is a brand-new vault worth seeding.
        var isNewVault = false
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                isNewVault = true
            } catch {
                errorMessage = "Couldn't open that folder: \(error.localizedDescription)"
                return
            }
        }

        let vault = Vault(root: url)
        self.vault = vault
        self.vaultKind = VaultLocations.kind(of: url)
        VaultBookmarks.remember(url)
        reload { [weak self] in
            guard let self else { return }
            if isNewVault && self.notes.isEmpty { self.seedWelcomeNote(in: vault) }
            if self.selectedNoteID == nil { self.selectedNoteID = self.visibleNotes.first?.id }
            self.loadDraftForSelection()
        }
        refreshGitStatus()

        watcher = VaultWatcher(root: url) { [weak self] in self?.handleExternalChange() }
        watcher?.start()
    }

    public func closeVault() {
        flushPendingSave()
        watcher?.stop()
        watcher = nil
        vault = nil
        notes = []
        visibleNotes = []
        folders = []
        tags = []
        draft = ""
        selectedNoteID = nil
        VaultBookmarks.forget()
    }

    /// Indexing runs off the main thread in two passes: metadata, so the list is
    /// on screen immediately, then contents, so snippets and tags fill in.
    ///
    /// The old single pass read every file synchronously on the main actor. On a
    /// large vault that froze the window; on a cloud folder it also *downloaded*
    /// every evicted file, because reading a placeholder is what materialises it.
    public func reload(then whenListed: (() -> Void)? = nil) {
        guard let vault else { return }
        let root = vault.root
        let generation = indexGeneration + 1
        indexGeneration = generation

        Task.detached(priority: .userInitiated) { [weak self] in
            let listing = Vault.metadata(root: root)
            let folders = Vault.folderPaths(root: root)
            await MainActor.run {
                guard let self, self.indexGeneration == generation else { return }
                self.notes = listing
                self.folders = folders
                self.refreshVisible()
                whenListed?()
            }
            await self?.loadContents(for: listing, generation: generation)
        }
    }

    /// Fills in contents in batches, republishing as it goes so the list fills
    /// rather than waiting for the whole vault.
    private func loadContents(for listing: [Note], generation: Int) async {
        var loaded: [Note.ID: String] = [:]
        for (index, note) in listing.enumerated() {
            if let text = Vault.loadContent(of: note) { loaded[note.id] = text }
            let isLast = index == listing.count - 1
            guard isLast || loaded.count % AppModel.indexBatch == 0 else { continue }

            let batch = loaded
            await MainActor.run { [weak self] in
                guard let self, self.indexGeneration == generation else { return }
                self.apply(contents: batch)
            }
        }
    }

    private static let indexBatch = 64

    private func apply(contents: [Note.ID: String]) {
        for index in notes.indices {
            guard !notes[index].isLoaded, let text = contents[notes[index].id] else { continue }
            notes[index].text = text
            notes[index].isLoaded = true
        }
        tags = Array(Set(notes.flatMap(\.tags))).sorted()
        refreshVisible()
    }

    /// Something outside the app touched the vault — a sync, a pull, another device.
    private func handleExternalChange() {
        guard vault != nil else { return }

        // Settle the open note against the file itself before reindexing. The
        // list is rebuilt asynchronously now, so consulting `notes` here would
        // compare the draft against the version from before the change.
        if let note = selectedNote, conflict == nil {
            if let onDisk = Vault.loadContent(of: note), onDisk != draft {
                if isDirty {
                    raiseConflict(for: note)
                } else {
                    draft = onDisk
                    if let index = notes.firstIndex(where: { $0.id == note.id }) {
                        notes[index].text = onDisk
                        notes[index].isLoaded = true
                    }
                    loadedModified = Vault.modificationDate(of: note.url)
                }
            }
        }

        let previousSelection = selectedNoteID
        reload { [weak self] in
            guard let self else { return }
            if let previousSelection, self.notes.contains(where: { $0.id == previousSelection }) {
                self.selectedNoteID = previousSelection
            } else {
                self.selectedNoteID = self.visibleNotes.first?.id
                self.lastLoadedNoteID = nil
                self.loadDraftForSelection()
            }
        }
        refreshGitStatus()
    }

    private func seedWelcomeNote(in vault: Vault) {
        guard let note = try? vault.createNote(title: "Welcome to Milky", body: AppModel.welcomeText) else { return }
        notes = [note]
        refreshVisible()
    }

    static let welcomeText = """
    Everything here is a **markdown file** in a folder you picked. No account, no database, \
    no lock-in — open the same folder in any other editor and it just works.

    ## Writing

    Type markdown and it formats as you go. The punctuation stays in the file but fades \
    back until your cursor lands on the line, so you can always see exactly what you wrote.

    - Lists continue when you press Return
    - [ ] Tasks work too — try ticking this one
    - Press ⌘B and ⌘I for **bold** and *italic*

    > Quotes, `inline code`, and fenced blocks all render live.

    ## Connecting notes

    Link notes with double brackets — [[Ideas]] creates that note if it doesn't exist yet. \
    Add #tags anywhere and they show up in the sidebar.

    ## Syncing

    Put this folder in iCloud Drive or Dropbox and it syncs itself. Make it a git \
    repository and the button in the bottom-left commits, pulls, and pushes.
    """

    // MARK: - Filtering

    private func refreshVisible() {
        visibleNotes = computeVisibleNotes()
    }

    func computeVisibleNotes() -> [Note] {
        var result = notes

        switch sidebarSelection {
        case .all:
            break
        case .folder(let path) where !path.isEmpty:
            result = result.filter { $0.folder == path || $0.folder.hasPrefix(path + "/") }
        case .folder:
            break
        case .tag(let tag):
            result = result.filter { $0.tags.contains(tag) }
        }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return result }
        let terms = query.lowercased().split(separator: " ").map(String.init)
        return result
            .compactMap { note -> (Note, Int)? in
                let title = note.title.lowercased()
                let body = note.text.lowercased()
                var score = 0
                for term in terms {
                    if title.contains(term) { score += 10 }
                    else if body.contains(term) { score += 1 }
                    else { return nil }
                }
                if title.hasPrefix(terms[0]) { score += 5 }
                return (note, score)
            }
            .sorted { $0.1 == $1.1 ? $0.0.modified > $1.0.modified : $0.1 > $1.1 }
            .map(\.0)
    }

    public var vaultRootURL: URL? { vault?.root }

    public var selectedNote: Note? {
        notes.first { $0.id == selectedNoteID }
    }

    public func noteCount(for selection: SidebarSelection) -> Int {
        switch selection {
        case .all: return notes.count
        case .folder(let path) where !path.isEmpty:
            return notes.filter { $0.folder == path || $0.folder.hasPrefix(path + "/") }.count
        case .folder: return notes.count
        case .tag(let tag): return notes.filter { $0.tags.contains(tag) }.count
        }
    }

    // MARK: - Editing

    public func loadDraftForSelection() {
        guard let note = selectedNote else {
            draft = ""
            lastLoadedNoteID = nil
            return
        }
        guard note.id != lastLoadedNoteID else { return }
        flushPendingSave()
        let loaded = ensureLoaded(note)
        draft = loaded.text
        isDirty = false
        adopt(loaded)
    }

    /// Takes a note as the open document. The id and the on-disk timestamp are
    /// set together on purpose: separating them is how the write guard ends up
    /// comparing against the *previous* note's file and inventing a conflict.
    /// Reads a note's contents now if the background pass has not reached it.
    /// One file is cheap; the point of the lazy index is to avoid reading *all*
    /// of them, not to leave the open note blank.
    @discardableResult
    private func ensureLoaded(_ note: Note) -> Note {
        guard !note.isLoaded else { return note }
        guard let text = Vault.loadContent(of: note) else { return note }
        var filled = note
        filled.text = text
        filled.isLoaded = true
        if let index = notes.firstIndex(where: { $0.id == note.id }) { notes[index] = filled }
        return filled
    }

    private func adopt(_ note: Note) {
        lastLoadedNoteID = note.id
        loadedModified = Vault.modificationDate(of: note.url)
    }

    public func draftChanged(_ text: String) {
        guard selectedNote != nil else { return }
        draft = text
        isDirty = true
        scheduleSave()
    }

    /// Autosave is debounced rather than per-keystroke: it keeps disk writes (and
    /// therefore Dropbox/iCloud sync churn) down without risking more than a second of work.
    private func scheduleSave() {
        // An unanswered conflict suspends autosave; resolving it resumes.
        guard conflict == nil else { return }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }

    public func flushPendingSave() {
        guard isDirty else { return }
        saveWork?.cancel()
        save()
    }

    private func save() {
        guard let vault, let note = selectedNote, isDirty, conflict == nil else { return }
        do {
            // Guarded: refuses rather than overwriting a file someone else has
            // written since it was read.
            loadedModified = try vault.write(draft, to: note.url, expecting: loadedModified)
            isDirty = false
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index].text = draft
                notes[index].modified = Date()
            }
            tags = Array(Set(notes.flatMap(\.tags))).sorted()
            refreshVisible()
        } catch is Vault.ConflictError {
            raiseConflict(for: note)
        } catch {
            errorMessage = "Couldn't save “\(note.title)”: \(error.localizedDescription)"
        }
    }

    /// Both versions are kept and the reader chooses. Nothing is written until
    /// they do.
    private func raiseConflict(for note: Note) {
        let theirs = (try? String(contentsOf: note.url, encoding: .utf8)) ?? ""
        guard theirs != draft else {
            // Identical content: whoever wrote it agreed with us.
            loadedModified = Vault.modificationDate(of: note.url)
            isDirty = false
            return
        }
        saveWork?.cancel()
        conflict = Conflict(noteID: note.id, title: note.title, mine: draft, theirs: theirs)
    }

    public func resolve(_ resolution: ConflictResolution) {
        guard let vault, let conflict, let note = notes.first(where: { $0.id == conflict.noteID })
        else { self.conflict = nil; return }
        self.conflict = nil

        do {
            switch resolution {
            case .keepMine:
                // Deliberate overwrite: no expectation, because the reader has
                // seen the other version and chosen against it.
                try vault.write(conflict.mine, to: note.url)
            case .takeTheirs:
                draft = conflict.theirs
            case .keepBoth:
                let stamp = ISO8601DateFormatter.conflictStamp.string(from: Date())
                _ = try vault.createNote(title: "\(note.title) (conflicted copy \(stamp))",
                                         in: note.folder, body: conflict.mine)
                draft = conflict.theirs
            }
            isDirty = false
            lastLoadedNoteID = nil
            reload()
            adopt(note)
        } catch {
            errorMessage = "Couldn't resolve the conflict: \(error.localizedDescription)"
        }
    }

    // MARK: - Note actions

    public func newNote() {
        guard let vault else { return }
        flushPendingSave()
        let folder: String
        if case .folder(let path) = sidebarSelection { folder = path } else { folder = "" }
        do {
            let note = try vault.createNote(title: "Untitled", in: folder)
            notes.insert(note, at: 0)
            refreshVisible()
            selectedNoteID = note.id
            draft = note.text
            adopt(note)
            isDirty = false
        } catch {
            errorMessage = "Couldn't create the note: \(error.localizedDescription)"
        }
    }

    public func rename(_ note: Note, to title: String) {
        guard let vault else { return }
        flushPendingSave()
        do {
            let renamed = try vault.rename(note, to: title)
            if let index = notes.firstIndex(where: { $0.id == note.id }) { notes[index] = renamed }
            refreshVisible()
            if selectedNoteID == note.id {
                selectedNoteID = renamed.id
                adopt(renamed)
            }
        } catch {
            errorMessage = "Couldn't rename the note: \(error.localizedDescription)"
        }
    }

    public func delete(_ note: Note) {
        guard let vault else { return }
        do {
            try vault.delete(note)
            let wasSelected = selectedNoteID == note.id
            notes.removeAll { $0.id == note.id }
            refreshVisible()
            if wasSelected {
                selectedNoteID = visibleNotes.first?.id
                lastLoadedNoteID = nil
                isDirty = false
                loadDraftForSelection()
            }
        } catch {
            errorMessage = "Couldn't delete the note: \(error.localizedDescription)"
        }
    }

    public func move(_ note: Note, to folder: String) {
        guard let vault else { return }
        flushPendingSave()
        do {
            let moved = try vault.move(note, toFolder: folder)
            if let index = notes.firstIndex(where: { $0.id == note.id }) { notes[index] = moved }
            refreshVisible()
            if selectedNoteID == note.id {
                selectedNoteID = moved.id
                adopt(moved)
            }
        } catch {
            errorMessage = "Couldn't move the note: \(error.localizedDescription)"
        }
    }

    public func createFolder(named name: String) {
        guard let vault else { return }
        do {
            let parent: String
            if case .folder(let path) = sidebarSelection { parent = path } else { parent = "" }
            let created = try vault.createFolder(named: name, in: parent)
            folders = vault.folders()
            sidebarSelection = .folder(created)
        } catch {
            errorMessage = "Couldn't create the folder: \(error.localizedDescription)"
        }
    }

    /// Follows a `[[wiki link]]`, creating the note if it doesn't exist yet.
    public func followWikiLink(_ target: String) {
        let needle = target.lowercased()
        if let match = notes.first(where: { $0.title.lowercased() == needle })
            ?? notes.first(where: { $0.relativePath.lowercased() == needle + ".md" }) {
            flushPendingSave()
            sidebarSelection = .all
            selectedNoteID = match.id
            loadDraftForSelection()
            return
        }
        guard let vault else { return }
        flushPendingSave()
        if let note = try? vault.createNote(title: target) {
            notes.insert(note, at: 0)
            refreshVisible()
            selectedNoteID = note.id
            draft = ""
            adopt(note)
        }
    }

    // MARK: - Git

    public func refreshGitStatus() {
        guard let vault else { gitStatus = .none; return }
        let sync = GitSync(root: vault.root)
        Task.detached { [weak self] in
            let status = sync.status()
            await MainActor.run { self?.gitStatus = status }
        }
    }

    public func syncNow() {
        guard let vault, !isSyncing else { return }
        flushPendingSave()
        isSyncing = true
        let sync = GitSync(root: vault.root)
        Task.detached { [weak self] in
            do {
                let status = try sync.sync()
                await MainActor.run {
                    self?.gitStatus = status
                    self?.isSyncing = false
                    self?.reload()
                }
            } catch {
                await MainActor.run {
                    self?.isSyncing = false
                    self?.errorMessage = AppModel.describe(error)
                }
            }
        }
    }

    public func initializeGit() {
        guard let vault else { return }
        let sync = GitSync(root: vault.root)
        do {
            try sync.initialize()
            refreshGitStatus()
        } catch {
            errorMessage = AppModel.describe(error)
        }
    }

    /// Some failures carry a fix. Dropping it on the floor is how a first sync
    /// turns into "Milky can't sync" rather than "run these two commands".
    static func describe(_ error: Error) -> String {
        let message = error.localizedDescription
        guard let suggestion = (error as? LocalizedError)?.recoverySuggestion else { return message }
        return message + "\n\n" + suggestion
    }

    // MARK: - Preferences

    private func persistTheme() {
        UserDefaults.standard.set(theme.typeface.rawValue, forKey: "milky.typeface")
        UserDefaults.standard.set(Double(theme.bodySize), forKey: "milky.bodySize")
    }

    private func restoreTheme() {
        let defaults = UserDefaults.standard
        var restored = Theme()
        if let raw = defaults.string(forKey: "milky.typeface"), let face = EditorTypeface(rawValue: raw) {
            restored.typeface = face
        }
        let size = defaults.double(forKey: "milky.bodySize")
        if size >= 11, size <= 28 { restored.bodySize = CGFloat(size) }
        theme = restored
    }
}

extension ISO8601DateFormatter {
    /// Filename-safe, and sorts correctly: 2026-09-06 14.03.
    static let conflictStamp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate,
                                   .withColonSeparatorInTime, .withSpaceBetweenDateAndTime]
        return formatter
    }()
}
