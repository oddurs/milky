#if canImport(AppKit)
import SwiftUI

// Milky has two type systems, and keeping them apart is the reason the app reads
// as native rather than as a web page in a window.
//
//   1. UI type — the chrome. Built on Apple's semantic text styles, so it picks
//      up the right metrics per platform (body is 13pt on macOS, 17pt on iOS)
//      and follows the user's Dynamic Type setting for free. Hardcoding point
//      sizes here is exactly what makes a Mac app feel foreign.
//
//   2. Reading type — the note itself. An explicit scale the reader controls,
//      because document text is content, not interface. That lives in `Theme`.
//
// Never reach past a role to a raw `.system(size:)`. If a role is missing, add it.

/// A named place text appears. Carries the font *and* the colour, so the two
/// cannot drift apart at a call site.
public enum TextRole {
    /// The note's title in the editor header.
    case documentTitle
    /// The timestamp under a document title.
    case documentMeta

    /// A sidebar section header: Folders, Tags.
    case sectionLabel
    /// A row in the sidebar.
    case sidebarItem

    /// The note's name in the note list.
    case rowTitle
    /// Date and snippet under a row title.
    case rowMeta

    /// Status bar along the bottom of the editor.
    case status
    /// A trailing count on a sidebar row.
    case badge

    /// Headline of an empty state.
    case emptyTitle
    /// The sentence under it, telling the reader what to do.
    case emptyDetail

    var font: Font {
        switch self {
        case .documentTitle: return .system(.title2, design: .default).weight(.bold)
        case .documentMeta:  return .system(.caption)
        case .sectionLabel:  return .system(.caption).weight(.semibold)
        case .sidebarItem:   return .system(.body)
        case .rowTitle:      return .system(.body).weight(.semibold)
        case .rowMeta:       return .system(.caption)
        case .status:        return .system(.caption)
        case .badge:         return .system(.caption).monospacedDigit()
        case .emptyTitle:    return .system(.headline)
        case .emptyDetail:   return .system(.caption)
        }
    }

    var color: Color {
        switch self {
        case .documentTitle, .rowTitle, .sidebarItem, .emptyTitle: return Palette.ink
        case .documentMeta, .status, .badge, .sectionLabel: return Palette.inkFaint
        case .rowMeta, .emptyDetail: return Palette.inkSoft
        }
    }

    /// Tracking. Apple's display sizes are drawn tighter than their text sizes;
    /// below ~17pt the system already handles it, so only the large roles differ.
    var tracking: CGFloat {
        switch self {
        case .documentTitle: return -0.4
        case .rowTitle: return -0.05
        default: return 0
        }
    }
}

public extension View {
    /// Applies a role's font, colour and tracking in one place.
    func textRole(_ role: TextRole) -> some View {
        self.font(role.font)
            .foregroundStyle(role.color)
            .tracking(role.tracking)
    }

    /// A role's type without its colour, for text that sits on a filled surface
    /// and has to supply its own contrast — a selected row, an accent button.
    func textRole(_ role: TextRole, color: Color) -> some View {
        self.font(role.font)
            .foregroundStyle(color)
            .tracking(role.tracking)
    }
}
#endif
