import AppKit
import MilkyUI

/// Development helper: `--snapshot <path>` renders the main window to a PNG from
/// inside the process, so design can be reviewed without screen-recording access.
/// `--vault <path>` opens a specific vault first. Neither flag ships in a release build.
enum DevSnapshot {
    static func vaultArgument() -> URL? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--vault"), index + 1 < args.count else { return nil }
        return URL(fileURLWithPath: (args[index + 1] as NSString).expandingTildeInPath)
    }

    /// `--appearance light|dark` pins the window appearance so both palettes can be
    /// reviewed without changing the system setting.
    static func applyAppearanceOverride() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--appearance"), index + 1 < args.count else { return }
        NSApp.appearance = args[index + 1] == "light" ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
    }

    /// `--caret <offset>` moves the insertion point before the snapshot, so the
    /// reveal-on-the-active-line behaviour can be captured either way.
    static func applyCaretOverride() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--caret"), index + 1 < args.count,
              let offset = Int(args[index + 1]) else { return }
        for window in NSApp.windows {
            guard let textView = firstTextView(in: window.contentView) else { continue }
            let clamped = min(offset, (textView.string as NSString).length)
            textView.setSelectedRange(NSRange(location: clamped, length: 0))
            textView.window?.makeFirstResponder(textView)
            return
        }
    }

    private static func firstTextView(in view: NSView?) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView { return textView }
        for subview in view.subviews {
            if let found = firstTextView(in: subview) { return found }
        }
        return nil
    }

    /// `MILKY_TOGGLE_CHECKBOX=1` clicks the first checkbox in the open note,
    /// through the same hit test a real click takes.
    ///
    /// An environment variable rather than a flag: adding an unrecognised
    /// `--argument` stopped the launch block from running at all, which cost an
    /// hour to find. The trace switch in the test harness works the same way.
    static func applyCheckboxClick() {
        guard ProcessInfo.processInfo.environment["MILKY_TOGGLE_CHECKBOX"] != nil else { return }
        for window in NSApp.windows {
            guard let textView = firstTextView(in: window.contentView) as? MilkyTextView else { continue }
            let hit = textView.clickFirstCheckbox()
            FileHandle.standardError.write("checkbox clicked: \(hit)\n".data(using: .utf8)!)
            return
        }
        FileHandle.standardError.write("checkbox clicked: no text view\n".data(using: .utf8)!)
    }

    static func scheduleIfRequested() {
        applyAppearanceOverride()
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--snapshot"), index + 1 < args.count else { return }
        let path = args[index + 1]
        let delay = args.firstIndex(of: "--delay").flatMap { $0 + 1 < args.count ? Double(args[$0 + 1]) : nil } ?? 2.5

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            applyCaretOverride()
            applyCheckboxClick()
            capture(to: path)
            if args.contains("--quit-after-snapshot") { NSApp.terminate(nil) }
        }
    }

    private static func capture(to path: String) {
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
              let view = window.contentView else { return }
        view.wantsLayer = true
        let size = view.bounds.size
        let scale = window.backingScaleFactor
        let pixels = CGSize(width: size.width * scale, height: size.height * scale)

        guard let context = CGContext(data: nil,
                                      width: Int(pixels.width), height: Int(pixels.height),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return }
        // CGContext is bottom-left origin; AppKit layers are top-left.
        context.translateBy(x: 0, y: pixels.height)
        context.scaleBy(x: scale, y: -scale)
        // Layer-tree rendering picks up the hosted SwiftUI sublayers that
        // cacheDisplay(in:to:) leaves out.
        view.layer?.render(in: context)

        guard let image = context.makeImage() else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = size
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write("snapshot written to \(path)\n".data(using: .utf8)!)
    }
}
