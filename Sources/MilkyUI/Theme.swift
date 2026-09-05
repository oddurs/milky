import SwiftUI

#if canImport(AppKit)
import AppKit
public typealias PlatformFont = NSFont
public typealias PlatformColor = NSColor
#else
import UIKit
public typealias PlatformFont = UIFont
public typealias PlatformColor = UIColor
#endif

/// The reading face of the editor. Sans is SF Pro — the Notes default — and Serif is
/// New York, Apple's own text serif, which is why both feel native rather than themed.
public enum EditorTypeface: String, CaseIterable, Identifiable, Sendable {
    case sans, serif, mono
    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .sans: return "System"
        case .serif: return "New York"
        case .mono: return "Monospaced"
        }
    }

    var design: PlatformFontDescriptor.SystemDesign {
        switch self {
        case .sans: return .default
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }
}

#if canImport(AppKit)
public typealias PlatformFontDescriptor = NSFontDescriptor
#else
public typealias PlatformFontDescriptor = UIFontDescriptor
#endif

/// Every size, weight, colour, and inset the app uses. Kept in one place so the
/// Mac and (later) iPhone builds stay visually identical.
public struct Theme: Sendable {
    public var typeface: EditorTypeface = .sans
    /// User-adjustable base body size; every other size scales from it.
    public var bodySize: CGFloat = 15

    public init(typeface: EditorTypeface = .sans, bodySize: CGFloat = 15) {
        self.typeface = typeface
        self.bodySize = bodySize
    }

    // MARK: - Metrics

    /// Roughly 68 characters at the default size — the measure that reads best.
    public var maxContentWidth: CGFloat { 720 }
    public var editorHorizontalInset: CGFloat { 32 }
    public var editorTopInset: CGFloat { 20 }
    public var lineHeightMultiple: CGFloat { 1.42 }
    /// Blank source lines are the paragraph break, rendered tighter than a full
    /// dropped line so blocks separate without the page feeling gappy.
    public var blankLineHeightMultiple: CGFloat { 0.62 }

    public func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return bodySize * 1.72
        case 2: return bodySize * 1.36
        case 3: return bodySize * 1.15
        default: return bodySize * 1.0
        }
    }

    public func headingWeight(_ level: Int) -> PlatformFont.Weight {
        level <= 2 ? .bold : .semibold
    }

    /// Space above a heading, so sections breathe without a manual blank line.
    public func headingSpacingBefore(_ level: Int) -> CGFloat {
        switch level {
        case 1: return bodySize * 1.1
        case 2: return bodySize * 1.0
        default: return bodySize * 0.8
        }
    }

    // MARK: - Fonts

    public func font(size: CGFloat, weight: PlatformFont.Weight = .regular, italic: Bool = false) -> PlatformFont {
        let base = PlatformFont.systemFont(ofSize: size, weight: weight)
        var descriptor = base.fontDescriptor
        if let designed = descriptor.withDesign(typeface.design) { descriptor = designed }
        if italic { descriptor = descriptor.withSymbolicTraits(italicTraits(descriptor)) }
        #if canImport(AppKit)
        return PlatformFont(descriptor: descriptor, size: size) ?? base
        #else
        return PlatformFont(descriptor: descriptor, size: size)
        #endif
    }

    public var bodyFont: PlatformFont { font(size: bodySize) }

    public func monoFont(size: CGFloat? = nil, weight: PlatformFont.Weight = .regular) -> PlatformFont {
        PlatformFont.monospacedSystemFont(ofSize: size ?? bodySize * 0.93, weight: weight)
    }

    #if canImport(AppKit)
    private func italicTraits(_ d: NSFontDescriptor) -> NSFontDescriptor.SymbolicTraits {
        d.symbolicTraits.union(.italic)
    }
    #else
    private func italicTraits(_ d: UIFontDescriptor) -> UIFontDescriptor.SymbolicTraits {
        d.symbolicTraits.union(.traitItalic)
    }
    #endif
}

/// Apple Notes' structure with our own accent: #C8FF00.
///
/// Lime is a *fill* colour, not an ink one. It carries 17.8:1 against black and
/// only 1.2:1 against white, so it can front a filled row or a checkbox but
/// cannot be text, a caret or a hairline on a light ground. `accentInk` is the
/// darkened companion for those, and it flips back to the pure lime in dark mode
/// where the contrast runs the other way.
public enum Palette {
    /// #C8FF00 — fills only.
    public static let accent = Color(red: 0.784, green: 1.0, blue: 0.0)
    public static let accentDeep = Color(red: 0.667, green: 0.855, blue: 0.0)

    /// Text drawn on a lime fill. Black clears 17.8:1; white manages 1.2:1.
    public static let onAccent = Color(red: 0.055, green: 0.075, blue: 0.0)

    #if canImport(AppKit)
    public static let accentPlatform = NSColor(red: 0.784, green: 1.0, blue: 0.0, alpha: 1)

    /// The accent as ink: dark olive on light grounds, pure lime on dark ones.
    /// Used for carets, list markers, icons and links — anything thin.
    public static let accentInkPlatform = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.784, green: 1.0, blue: 0.0, alpha: 1)
            : NSColor(red: 0.353, green: 0.451, blue: 0.0, alpha: 1)
    }

    public static let onAccentPlatform = NSColor(red: 0.055, green: 0.075, blue: 0.0, alpha: 1)

    /// SwiftUI view of `accentInkPlatform`, for icons and labels.
    public static let accentInk = Color(nsColor: accentInkPlatform)

    /// Body text. Not pure black — Notes sits a touch softer.
    public static let text = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.925, green: 0.929, blue: 0.914, alpha: 1)
            : NSColor(red: 0.098, green: 0.102, blue: 0.090, alpha: 1)
    }

    public static let secondaryText = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.596, green: 0.604, blue: 0.580, alpha: 1)
            : NSColor(red: 0.427, green: 0.435, blue: 0.412, alpha: 1)
    }

    /// Markdown punctuation: present, but pushed well back.
    public static let syntax = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1, alpha: 0.26) : NSColor(white: 0, alpha: 0.22)
    }

    public static let syntaxActive = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1, alpha: 0.45) : NSColor(white: 0, alpha: 0.38)
    }

    public static let link = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.42, green: 0.68, blue: 0.98, alpha: 1)
            : NSColor(red: 0.10, green: 0.44, blue: 0.86, alpha: 1)
    }

    public static let codeText = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.94, green: 0.62, blue: 0.55, alpha: 1)
            : NSColor(red: 0.72, green: 0.20, blue: 0.30, alpha: 1)
    }

    public static let codeBackground = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1, alpha: 0.07) : NSColor(white: 0, alpha: 0.045)
    }

    public static let quoteBar = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1, alpha: 0.22) : NSColor(white: 0, alpha: 0.18)
    }

    public static let rule = NSColor(name: nil) { appearance in
        appearance.isDark ? NSColor(white: 1, alpha: 0.14) : NSColor(white: 0, alpha: 0.12)
    }

    public static let tagBackground = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.784, green: 1.0, blue: 0.0, alpha: 0.20)
            : NSColor(red: 0.784, green: 1.0, blue: 0.0, alpha: 0.38)
    }

    public static let tagText = NSColor(name: nil) { appearance in
        appearance.isDark
            ? NSColor(red: 0.831, green: 0.949, blue: 0.478, alpha: 1)
            : NSColor(red: 0.278, green: 0.353, blue: 0.0, alpha: 1)
    }
    #endif
}

#if canImport(AppKit)
extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}
#endif
