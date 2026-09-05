#if canImport(AppKit)
import SwiftUI
import MilkyStorage

public struct RootView: View {
    @EnvironmentObject var model: AppModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init() {}

    public var body: some View {
        Group {
            if model.vault == nil {
                WelcomeView { model.open($0) }
            } else {
                splitView
            }
        }
        .tint(Palette.accent)
        .alert("Something went wrong",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 320)
        } content: {
            NoteListView()
                .navigationSplitViewColumnWidth(min: 230, ideal: 280, max: 420)
        } detail: {
            EditorView()
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup {
                Button(action: model.newNote) {
                    Label("New Note", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New Note (⌘N)")
            }
        }
    }
}

/// Type size and reading face. Lives in a popover rather than a settings window,
/// because it's the kind of thing you change while looking at your text.
public struct AppearancePopover: View {
    @EnvironmentObject var model: AppModel

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Appearance").font(.system(size: 12, weight: .semibold))

            Picker("Face", selection: Binding(get: { model.theme.typeface },
                                              set: { model.theme.typeface = $0 })) {
                ForEach(EditorTypeface.allCases) { face in
                    Text(face.label).tag(face)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 10) {
                Image(systemName: "textformat.size.smaller").foregroundStyle(.secondary)
                Slider(value: Binding(get: { Double(model.theme.bodySize) },
                                      set: { model.theme.bodySize = CGFloat($0.rounded()) }),
                       in: 12...24, step: 1)
                Image(systemName: "textformat.size.larger").foregroundStyle(.secondary)
            }

            Text("\(Int(model.theme.bodySize)) pt")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 260)
    }
}
#endif
