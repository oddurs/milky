#if canImport(AppKit)
import SwiftUI

/// The trailing number on a sidebar row. Tabular figures so a column of them
/// does not shuffle sideways as counts change.
public struct CountBadge: View {
    let value: Int

    public init(_ value: Int) { self.value = value }

    public var body: some View {
        Text("\(value)")
            .textRole(.badge)
            .accessibilityLabel("\(value) notes")
    }
}
#endif
