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

    /// Math is set in New York regardless of the reading face: a serif is what
    /// makes an equation read as an equation, and it is the system's own.
    public func mathFont(size: CGFloat, italic: Bool = false) -> PlatformFont {
        let base = PlatformFont.systemFont(ofSize: size, weight: .regular)
        var descriptor = base.fontDescriptor
        if let serif = descriptor.withDesign(.serif) { descriptor = serif }
        if italic {
            #if canImport(AppKit)
            descriptor = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.italic))
            #else
            descriptor = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) ?? descriptor
            #endif
        }
        #if canImport(AppKit)
        return PlatformFont(descriptor: descriptor, size: size) ?? base
        #else
        return PlatformFont(descriptor: descriptor, size: size)
        #endif
    }

    public func monoFont(size: CGFloat? = nil,
                         weight: PlatformFont.Weight = .regular,
                         italic: Bool = false) -> PlatformFont {
        let base = PlatformFont.monospacedSystemFont(ofSize: size ?? bodySize * 0.93, weight: weight)
        guard italic else { return base }
        #if canImport(AppKit)
        let descriptor = base.fontDescriptor.withSymbolicTraits(base.fontDescriptor.symbolicTraits.union(.italic))
        return PlatformFont(descriptor: descriptor, size: base.pointSize) ?? base
        #else
        return base
        #endif
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

// Colour lives in DesignSystem/Tokens.generated.swift (`Ink` for AppKit, `Palette`
// for SwiftUI). `Theme` above is the *reading* scale only: the size and face of
// the note itself, which the reader controls and the UI chrome must not follow.
