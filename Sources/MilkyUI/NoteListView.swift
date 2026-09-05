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
        VStack(spacing: 6) {
            Text(model.searchText.isEmpty ? "No Notes" : "No Results")
                .font(.system(size: 15, weight: .semibold))
            if model.searchText.isEmpty {
                Text("Press ⌘N to write one.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, 40)
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
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(filled ? AnyShapeStyle(Palette.onAccent) : AnyShapeStyle(.primary))
            HStack(spacing: 5) {
                Text(NoteRow.dateLabel(note.modified))
                    .font(.system(size: 11.5))
                    .foregroundStyle(filled ? AnyShapeStyle(Palette.onAccent.opacity(0.82)) : AnyShapeStyle(.secondary))
                Text(note.snippet.isEmpty ? "No additional text" : note.snippet)
                    .font(.system(size: 11.5))
                    .foregroundStyle(filled ? AnyShapeStyle(Palette.onAccent.opacity(0.62)) : AnyShapeStyle(.tertiary))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // No inset: an inset here lets SwiftUI's own selection fill show along the
        // edge, and the system's is blue.
        .listRowBackground(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
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
