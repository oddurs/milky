#if canImport(AppKit)
import SwiftUI
import AppKit

/// Reaches the `NSWindow` behind a SwiftUI scene so it can be given the
/// behaviours Mac users expect and SwiftUI does not expose: a remembered frame,
/// and a toolbar that reads as part of the window rather than a strip on top.
struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // The window is nil until the view joins the hierarchy.
        DispatchQueue.main.async {
            if let window = view.window { configure(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /// Restores the window's size and position from the last run, the way any
    /// document-shaped Mac app does. Without this Milky reopens at the default
    /// size on every launch, wherever the system decides to put it.
    func restoresWindowFrame(named name: String) -> some View {
        background(
            WindowAccessor { window in
                window.setFrameAutosaveName(name)
                window.titlebarAppearsTransparent = false
                window.isMovableByWindowBackground = false
                // A vault is one window's worth of state; tabs would imply
                // several vaults open at once, which the model does not support.
                window.tabbingMode = .disallowed
            }
            .frame(width: 0, height: 0)
        )
    }
}
#endif
