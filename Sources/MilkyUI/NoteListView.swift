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
                            Button("Rename…") { renameTarget = note }
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
        .sheet(item: $renameTarget) { note in
            RenameSheet(note: note) { model.rename(note, to: $0) }
        }
        .navigationTitle(model.sidebarSelection.title)
    }

    @State private var renameTarget: Note?

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

    var body: some View {
        // On the yellow selection fill, text has to go dark in both appearances —
        // white-on-yellow fails contrast the same way in light and dark mode.
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.black.opacity(0.88)) : AnyShapeStyle(.primary))
            HStack(spacing: 5) {
                Text(NoteRow.dateLabel(note.modified))
                    .font(.system(size: 11.5))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.black.opacity(0.7)) : AnyShapeStyle(.secondary))
                Text(note.snippet.isEmpty ? "No additional text" : note.snippet)
                    .font(.system(size: 11.5))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.black.opacity(0.5)) : AnyShapeStyle(.tertiary))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .listRowBackground(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(Palette.accent.opacity(0.9)) : AnyShapeStyle(Color.clear))
                .padding(.vertical, 1)
        )
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

private struct RenameSheet: View {
    let note: Note
    let onCommit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Note").font(.system(size: 13, weight: .semibold))
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit { commit() }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Rename") { commit() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .onAppear { title = note.title }
    }

    private func commit() {
        onCommit(title)
        dismiss()
    }
}
#endif
