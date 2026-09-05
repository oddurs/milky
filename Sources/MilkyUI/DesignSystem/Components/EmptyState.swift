#if canImport(AppKit)
import SwiftUI

/// The screen when there is nothing to show. Three places needed one — an empty
/// vault, a search with no matches, and no note selected — and all three had
/// been written separately.
///
/// An empty state is an instruction, not an apology: say what is there and what
/// to do next.
public struct EmptyState: View {
    let symbol: String?
    let title: String
    let detail: String?

    public init(symbol: String? = nil, title: String, detail: String? = nil) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
    }

    public var body: some View {
        VStack(spacing: Space.sm) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(Palette.inkFaint.opacity(0.55))
                    .padding(.bottom, Space.xxs)
            }
            Text(title).textRole(.emptyTitle)
            if let detail {
                Text(detail)
                    .textRole(.emptyDetail)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
#endif
