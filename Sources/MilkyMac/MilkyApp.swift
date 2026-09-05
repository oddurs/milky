import SwiftUI
import AppKit
import MilkyUI
import MilkyStorage

/// SwiftUI's `App` lifecycle plus the few AppKit touches that make a document-style
/// window feel right: a unified toolbar, and a flush-to-disk on quit.
@main
struct MilkyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    @State private var showingAppearance = false

    var body: some Scene {
        Window("Milky", id: "main") {
            RootView()
                .environmentObject(model)
                .frame(minWidth: 720, minHeight: 460)
                .onAppear {
                    delegate.model = model
                    if let vault = DevSnapshot.vaultArgument() { model.open(vault) }
                    DevSnapshot.scheduleIfRequested()
                }
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") { model.newNote() }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(model.vault == nil)

                Divider()

                Button("Open Vault…") { openVault(model) }
                    .keyboardShortcut("o", modifiers: .command)

                Menu("Open Recent") {
                    ForEach(VaultBookmarks.recents(), id: \.self) { url in
                        Button(url.lastPathComponent) { model.open(url) }
                    }
                }

                Button("Close Vault") { model.closeVault() }
                    .disabled(model.vault == nil)
            }

            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Bold") { EditorCommands.wrap("**") }
                    .keyboardShortcut("b", modifiers: .command)
                Button("Italic") { EditorCommands.wrap("*") }
                    .keyboardShortcut("i", modifiers: .command)
                Button("Inline Code") { EditorCommands.wrap("`") }
                    .keyboardShortcut("e", modifiers: .command)
                Button("Strikethrough") { EditorCommands.wrap("~~") }
                    .keyboardShortcut("u", modifiers: [.command, .shift])

                Divider()
                Button("Heading") { EditorCommands.linePrefix("# ") }
                    .keyboardShortcut("1", modifiers: [.command, .control])
                Button("Subheading") { EditorCommands.linePrefix("## ") }
                    .keyboardShortcut("2", modifiers: [.command, .control])
                Button("Bulleted List") { EditorCommands.linePrefix("- ") }
                    .keyboardShortcut("8", modifiers: [.command, .shift])
                Button("Checklist") { EditorCommands.linePrefix("- [ ] ") }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Quote") { EditorCommands.linePrefix("> ") }
                    .keyboardShortcut("'", modifiers: [.command, .shift])
            }

            CommandGroup(after: .toolbar) {
                Button("Bigger Text") { model.theme.bodySize = min(24, model.theme.bodySize + 1) }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Smaller Text") { model.theme.bodySize = max(12, model.theme.bodySize - 1) }
                    .keyboardShortcut("-", modifiers: .command)
            }

            CommandMenu("Vault") {
                Button("Sync Now") { model.syncNow() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!model.gitStatus.isRepository || model.isSyncing)
                Button("Set Up Git Sync") { model.initializeGit() }
                    .disabled(model.vault == nil || model.gitStatus.isRepository)
                Divider()
                Button("Reload from Disk") { model.reload() }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Reveal Vault in Finder") {
                    if let root = model.vaultRootURL { NSWorkspace.shared.open(root) }
                }
                .disabled(model.vault == nil)
            }
        }
    }

    private func openVault(_ model: AppModel) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Open Vault"
        if panel.runModal() == .OK, let url = panel.url { model.open(url) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { model?.flushPendingSave() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
