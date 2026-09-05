#if canImport(AppKit)
import SwiftUI
import MilkyCore

/// The right-hand pane: a Notes-style title line above the live markdown document.
struct EditorView: View {
    @EnvironmentObject var model: AppModel
    @State private var titleField: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        Group {
            if let note = model.selectedNote {
                content(for: note)
            } else {
                placeholder
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func content(for note: Note) -> some View {
        VStack(spacing: 0) {
            header(for: note)
            MarkdownEditor(text: Binding(get: { model.draft },
                                         set: { model.draftChanged($0) }),
                           theme: model.theme,
                           documentID: note.id,
                           onLink: handleLink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer(for: note)
        }
        .onAppear { titleField = note.title }
        .onChange(of: note.id) { _, _ in titleField = note.title }
    }

    private func header(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TextField("Title", text: $titleField)
                .textFieldStyle(.plain)
                .font(.system(size: model.theme.bodySize * 1.62, weight: .bold))
                .focused($titleFocused)
                .onSubmit { commitTitle(note) }
                .onChange(of: titleFocused) { _, focused in
                    if !focused { commitTitle(note) }
                }
            Text(EditorView.timestamp(note.modified))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: model.theme.maxContentWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, model.theme.editorHorizontalInset)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private func footer(for note: Note) -> some View {
        HStack(spacing: 10) {
            Text(EditorView.wordCount(model.draft))
            if model.isDirty {
                Text("Saving…").transition(.opacity)
            }
            Spacer()
            Text(note.relativePath).lineLimit(1).truncationMode(.head)
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.4) }
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "note.text")
                .font(.system(size: 42, weight: .thin))
                .foregroundStyle(.quaternary)
            Text("No Note Selected")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commitTitle(_ note: Note) {
        let trimmed = titleField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != note.title else {
            titleField = note.title
            return
        }
        model.rename(note, to: trimmed)
    }

    private func handleLink(_ payload: String, _ kind: TokenKind) {
        switch kind {
        case .wikiLink:
            model.followWikiLink(payload)
        case .tag:
            model.sidebarSelection = .tag(payload)
        case .link:
            if let url = URL(string: payload), url.scheme != nil {
                NSWorkspace.shared.open(url)
            } else {
                model.followWikiLink(payload)
            }
        default:
            break
        }
    }

    static func wordCount(_ text: String) -> String {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        return words == 1 ? "1 word" : "\(words) words"
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "d MMMM 'at' HH:mm"
            : "d MMMM yyyy 'at' HH:mm"
        return formatter.string(from: date)
    }
}
#endif
