#if canImport(AppKit)
import SwiftUI
import MilkyStorage


/// A folder path expanded into a tree, so nested vault directories nest in the sidebar.
struct FolderNode: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var children: [FolderNode]

    static func tree(from paths: [String]) -> [FolderNode] {
        var roots: [FolderNode] = []

        func insert(_ components: [Substring], prefix: String, into nodes: inout [FolderNode]) {
            guard let first = components.first else { return }
            let path = prefix.isEmpty ? String(first) : "\(prefix)/\(first)"
            if let index = nodes.firstIndex(where: { $0.path == path }) {
                insert(Array(components.dropFirst()), prefix: path, into: &nodes[index].children)
            } else {
                var node = FolderNode(name: String(first), path: path, children: [])
                insert(Array(components.dropFirst()), prefix: path, into: &node.children)
                nodes.append(node)
            }
        }

        for path in paths.sorted() {
            insert(path.split(separator: "/"), prefix: "", into: &roots)
        }
        return roots
    }
}

struct SidebarView: View {
    @EnvironmentObject var model: AppModel
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var renamingFolder: String?
    @State private var renameText = ""
    @State private var deletingFolder: String?

    private func beginRename(_ path: String, _ name: String) {
        renameText = name
        renamingFolder = path
    }

    private func confirmDelete(_ path: String) { deletingFolder = path }

    var body: some View {
        List(selection: $model.sidebarSelection) {
            Section(model.vault?.root.lastPathComponent ?? "Milky") {
                row(.all, title: "All Notes", symbol: "note.text")
            }

            let tree = FolderNode.tree(from: model.folders)
            if !tree.isEmpty {
                Section("Folders") {
                    ForEach(tree) { node in
                        FolderRow(node: node, onRename: beginRename, onDelete: confirmDelete)
                    }
                }
            }

            if !model.tags.isEmpty {
                Section("Tags") {
                    ForEach(model.tags, id: \.self) { tag in
                        row(.tag(tag), title: "#\(tag)", symbol: "number")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { footer }
        .sheet(isPresented: $isCreatingFolder) { newFolderSheet }
        .alert("Rename Folder", isPresented: Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { renamingFolder = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let path = renamingFolder { model.renameFolder(path, to: renameText) }
                renamingFolder = nil
            }
            Button("Cancel", role: .cancel) { renamingFolder = nil }
        } message: {
            Text("The notes inside move with it.")
        }
        .alert("Delete Folder", isPresented: Binding(
            get: { deletingFolder != nil },
            set: { if !$0 { deletingFolder = nil } }
        )) {
            Button("Move to Trash", role: .destructive) {
                if let path = deletingFolder { model.deleteFolder(path) }
                deletingFolder = nil
            }
            Button("Cancel", role: .cancel) { deletingFolder = nil }
        } message: {
            // Say how many notes go with it — the whole point of the confirmation.
            let count = deletingFolder.map { model.noteCount(inFolder: $0) } ?? 0
            Text(count == 0
                 ? "This folder is empty. It goes to the Trash, where you can put it back."
                 : "\(count) note\(count == 1 ? "" : "s") go to the Trash with it, "
                   + "where you can put them back.")
        }
    }

    @ViewBuilder
    private func row(_ selection: SidebarSelection, title: String, symbol: String) -> some View {
        SidebarRow(symbol: symbol, title: title, count: model.noteCount(for: selection))
            .tag(selection)
    }

    private struct FolderRow: View {
        let node: FolderNode
        let onRename: (String, String) -> Void
        let onDelete: (String) -> Void
        @EnvironmentObject var model: AppModel

        var body: some View {
            if node.children.isEmpty {
                label
            } else {
                DisclosureGroup {
                    ForEach(node.children) { child in
                        FolderRow(node: child, onRename: onRename, onDelete: onDelete)
                    }
                } label: {
                    label
                }
            }
        }

        private var label: some View {
            SidebarRow(symbol: "folder", title: node.name,
                       count: model.noteCount(for: .folder(node.path)))
                .tag(SidebarSelection.folder(node.path))
                .contextMenu {
                    Button("Rename…") { onRename(node.path, node.name) }
                    Menu("Move to") {
                        Button("Top Level") { model.moveFolder(node.path, into: "") }
                        ForEach(model.folders.filter {
                            $0 != node.path && !$0.hasPrefix(node.path + "/")
                        }, id: \.self) { destination in
                            Button(destination) { model.moveFolder(node.path, into: destination) }
                        }
                    }
                    Button("Reveal in Finder") {
                        if let root = model.vaultRootURL {
                            NSWorkspace.shared.activateFileViewerSelecting([root.appending(path: node.path)])
                        }
                    }
                    Divider()
                    Button("Delete", role: .destructive) { onDelete(node.path) }
                }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)
            HStack(spacing: 6) {
                Button {
                    isCreatingFolder = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("New Folder")

                Spacer()
                SyncStatusView()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
    }

    private var newFolderSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Folder").font(.system(size: 13, weight: .semibold))
            TextField("Name", text: $newFolderName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .onSubmit(commitFolder)
            HStack {
                Spacer()
                Button("Cancel") { isCreatingFolder = false }.keyboardShortcut(.cancelAction)
                Button("Create", action: commitFolder)
                    .keyboardShortcut(.defaultAction)
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    private func commitFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        model.createFolder(named: name)
        newFolderName = ""
        isCreatingFolder = false
    }
}

/// Shows where the vault syncs, and offers the one action that isn't automatic: git push/pull.
struct SyncStatusView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.gitStatus.isRepository {
                Button(action: model.syncNow) {
                    HStack(spacing: 4) {
                        if model.isSyncing {
                            ProgressView().controlSize(.mini).scaleEffect(0.7)
                        } else {
                            Image(systemName: badgeSymbol)
                        }
                        Text(label)
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .disabled(model.isSyncing)
                .help("Commit, pull, and push this vault")
            } else {
                HStack(spacing: 4) {
                    Image(systemName: model.vaultKind.symbol)
                    Text(model.vaultKind.label)
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var badgeSymbol: String {
        let status = model.gitStatus
        if status.dirtyCount > 0 || status.ahead > 0 { return "arrow.triangle.2.circlepath" }
        if status.behind > 0 { return "arrow.down.circle" }
        return "checkmark.circle"
    }

    private var label: String {
        let status = model.gitStatus
        if model.isSyncing { return "Syncing…" }
        if status.dirtyCount > 0 { return "\(status.dirtyCount) changed" }
        if status.ahead > 0 { return "\(status.ahead) to push" }
        if status.behind > 0 { return "\(status.behind) to pull" }
        return status.branch
    }
}
#endif
