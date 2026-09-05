#if canImport(AppKit)
import SwiftUI
import MilkyStorage

/// First run. Every option here is a folder — there is no account to create.
struct WelcomeView: View {
    @EnvironmentObject var model: AppModel
    var onChoose: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(Palette.accentInk)
                Text("Milky")
                    .font(.system(size: 27, weight: .bold))
                Text("Your notes are plain markdown files in a folder you choose.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 52)
            .padding(.bottom, 30)

            VStack(spacing: 8) {
                if let iCloud = VaultLocations.iCloudDrive {
                    option(.iCloud, subtitle: "Syncs to your iPhone automatically") {
                        onChoose(iCloud.appending(path: "Milky"))
                    }
                }
                if let dropbox = VaultLocations.dropbox {
                    option(.dropbox, subtitle: "Syncs wherever Dropbox runs") {
                        onChoose(dropbox.appending(path: "Milky"))
                    }
                }
                option(.git, subtitle: "Open a folder that's already a git repository", action: chooseFolder)
                option(.local, subtitle: "Pick any folder on this Mac", action: chooseFolder)
            }
            .frame(width: 400)

            let recents = VaultBookmarks.recents()
            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recent")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    ForEach(recents.prefix(4), id: \.self) { url in
                        Button {
                            onChoose(url)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: VaultLocations.kind(of: url).symbol)
                                    .foregroundStyle(Palette.accentInk)
                                Text(url.lastPathComponent)
                                Text(url.deletingLastPathComponent().path.replacingOccurrences(
                                    of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.head)
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(.link)
                    }
                }
                .frame(width: 400, alignment: .leading)
                .padding(.top, 26)
            }

            Spacer()
        }
        .frame(minWidth: 560, minHeight: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func option(_ kind: VaultKind, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.accentInk)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.label).font(.system(size: 13, weight: .medium))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Open Vault"
        panel.message = "Choose the folder that holds your markdown notes."
        if panel.runModal() == .OK, let url = panel.url { onChoose(url) }
    }
}
#endif
