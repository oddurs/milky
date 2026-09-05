#if canImport(AppKit)
import SwiftUI
import AppKit
import MilkyCore

/// Bridges the AppKit editing surface into SwiftUI.
public struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var theme: Theme
    /// Changes identity when a different note is opened, so the view knows to reload
    /// the whole document rather than diffing it.
    var documentID: String
    var onLink: (String, TokenKind) -> Void

    public init(text: Binding<String>, theme: Theme, documentID: String,
                onLink: @escaping (String, TokenKind) -> Void) {
        self._text = text
        self.theme = theme
        self.documentID = documentID
        self.onLink = onLink
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let (scroll, textView) = MilkyTextView.make()
        textView.theme = theme
        textView.onTextChange = { [weak textView] newText in
            guard textView != nil else { return }
            context.coordinator.isApplyingModelUpdate = true
            self.text = newText
            context.coordinator.isApplyingModelUpdate = false
        }
        textView.onLinkActivation = onLink
        textView.load(text)
        context.coordinator.textView = textView
        context.coordinator.documentID = documentID
        return scroll
    }

    public func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? MilkyTextView else { return }
        textView.onLinkActivation = onLink

        if context.coordinator.documentID != documentID {
            context.coordinator.documentID = documentID
            textView.theme = theme
            textView.load(text)
            return
        }
        if textView.theme.typeface != theme.typeface || textView.theme.bodySize != theme.bodySize {
            textView.theme = theme
        }
        // Only push text back when it changed underneath us (external sync, undo of a
        // rename); echoing our own keystrokes would fight the caret.
        if textView.string != text, !context.coordinator.isApplyingModelUpdate {
            let selection = textView.selectedRange()
            textView.load(text)
            let safe = NSRange(location: min(selection.location, (text as NSString).length), length: 0)
            textView.setSelectedRange(safe)
        }
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator {
        weak var textView: MilkyTextView?
        var documentID: String = ""
        var isApplyingModelUpdate = false
    }
}

/// Formatting commands routed from the menu bar to whichever editor has focus.
public enum EditorCommands {
    static func focusedTextView() -> MilkyTextView? {
        NSApp.keyWindow?.firstResponder as? MilkyTextView
    }

    public static func wrap(_ marker: String) { focusedTextView()?.toggleWrap(marker) }
    public static func linePrefix(_ prefix: String) { focusedTextView()?.toggleLinePrefix(prefix) }
}
#endif
