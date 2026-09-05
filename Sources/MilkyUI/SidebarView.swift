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

    var body: some View {
        List(selection: $model.sidebarSelection) {
            Section(model.vault?.root.lastPathComponent ?? "Milky") {
                row(.all, title: "All Notes", symbol: "note.text")
            }

            let tree = FolderNode.tree(from: model.folders)
            if !tree.isEmpty {
                Section("Folders") {
                    ForEach(tree) { node in
                        FolderRow(node: node)
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
    }

    @ViewBuilder
    private func row(_ selection: SidebarSelection, title: String, symbol: String) -> some View {
        Label {
            HStack {
                Text(title).lineLimit(1)
                Spacer()
                Text("\(model.noteCount(for: selection))")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(Palette.accent)
        }
        .tag(selection)
    }

    private struct FolderRow: View {
        let node: FolderNode
        @EnvironmentObject var model: AppModel

        var body: some View {
            if node.children.isEmpty {
                label
            } else {
                DisclosureGroup {
                    ForEach(node.children) { child in FolderRow(node: child) }
                } label: {
                    label
                }
            }
        }

        private var label: some View {
            Label {
                HStack {
                    Text(node.name).lineLimit(1)
                    Spacer()
                    Text("\(model.noteCount(for: .folder(node.path)))")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            } icon: {
                Image(systemName: "folder").foregroundStyle(Palette.accent)
            }
            .tag(SidebarSelection.folder(node.path))
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
