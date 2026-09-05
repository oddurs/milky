#if canImport(AppKit)
import SwiftUI

/// One line in the sidebar: a symbol, a label, and a count. Folders and tags and
/// All Notes were each drawing this by hand, with the icon colour diverging.
///
/// The symbol takes `accentInk`, never `accent` — a lime glyph on the light
/// sidebar material scores 1.2:1 and disappears.
public struct SidebarRow: View {
    let symbol: String
    let title: String
    let count: Int?

    public init(symbol: String, title: String, count: Int? = nil) {
        self.symbol = symbol
        self.title = title
        self.count = count
    }

    public var body: some View {
        Label {
            HStack(spacing: Space.xs) {
                Text(title).lineLimit(1)
                Spacer(minLength: Space.xs)
                if let count { CountBadge(count) }
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(Palette.accentInk)
        }
        .textRole(.sidebarItem)
    }
}
#endif
