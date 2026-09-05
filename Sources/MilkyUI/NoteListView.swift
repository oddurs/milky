#if canImport(AppKit)
import SwiftUI
import MilkyCore

/// The middle column: every note in the current folder, newest first.
struct NoteListView: View {
    @EnvironmentObject var model: AppModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        let notes = model.visibleNotes
        VStack(spacing: 0) {
            List(selection: $model.selectedNoteID) {
                ForEach(notes) { note in
                    NoteRow(note: note, isSelected: note.id == model.selectedNoteID)
                        .tag(note.id)
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button("Rename…") {
                                renameText = note.title
                                renameTarget = note
                            }
                            Menu("Move to") {
                                Button("All Notes") { model.move(note, to: "") }
                                ForEach(model.folders, id: \.self) { folder in
                                    Button(folder) { model.move(note, to: folder) }
                                }
                            }
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([note.url])
                            }
                            Divider()
                            Button("Delete", role: .destructive) { model.delete(note) }
                        }
                }
            }
            .listStyle(.inset)
            .focusEffectDisabled()
            .scrollContentBackground(.hidden)
            .background(listBackground)
            .overlay(alignment: .center) {
                if notes.isEmpty { emptyState }
            }
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search")
        .onChange(of: model.selectedNoteID) { _, _ in model.loadDraftForSelection() }
        .alert("Rename Note", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Title", text: $renameText)
            Button("Rename") {
                if let note = renameTarget { model.rename(note, to: renameText) }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        } message: {
            Text("The filename is the title, so this renames the file too.")
        }
        .navigationTitle(model.sidebarSelection.title)
    }

    @State private var renameTarget: Note?
    @State private var renameText = ""

    private var listBackground: some View {
        Color(nsColor: .textBackgroundColor).opacity(0.55)
    }

    private var emptyState: some View {
        model.searchText.isEmpty
            ? EmptyState(title: "No Notes", detail: "Press ⌘N to write one.")
            : EmptyState(title: "No Results", detail: "Nothing here matches “\(model.searchText)”.")
    }
}

private struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    @Environment(\.controlActiveState) private var activeState

    /// Selected *and* the window is the active one.
    private var filled: Bool { isSelected && activeState != .inactive }

    var body: some View {
        // Text on the filled accent must be white — #7624F4 gives white 6.3:1 and
        // black only 3.3:1. When the list loses focus the fill drops to a neutral
        // tint and the text returns to normal, the way every Mac list behaves.
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(note.title)
                .lineLimit(1)
                .textRole(.rowTitle, color: filled ? Palette.onAccent : Palette.ink)
            HStack(spacing: Space.xs) {
                Text(NoteRow.dateLabel(note.modified))
                    .textRole(.rowMeta, color: filled ? Palette.onAccent.opacity(0.82) : Palette.inkSoft)
                Text(note.snippet.isEmpty ? "No additional text" : note.snippet)
                    .lineLimit(1)
                    .textRole(.rowMeta, color: filled ? Palette.onAccent.opacity(0.62) : Palette.inkFaint)
            }
        }
        .padding(.vertical, Space.sm)
        .padding(.horizontal, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // No inset: an inset here lets SwiftUI's own selection fill show along the
        // edge, and the system's is blue.
        .listRowBackground(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(rowFill)
        )
    }

    private var rowFill: AnyShapeStyle {
        if filled { return AnyShapeStyle(Palette.accent) }
        if isSelected { return AnyShapeStyle(Color.primary.opacity(0.09)) }
        return AnyShapeStyle(Color.clear)
    }

    /// Today shows a time, this week a weekday, older an actual date — the way Notes does it.
    static func dateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if let week = calendar.date(byAdding: .day, value: -6, to: Date()), date > week {
            formatter.dateFormat = "EEEE"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "d MMM"
        } else {
            formatter.dateFormat = "d MMM yyyy"
        }
        return formatter.string(from: date)
    }
}

#endif
