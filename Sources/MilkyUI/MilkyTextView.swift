#if canImport(AppKit)
import AppKit
import MilkyCore

/// The editing surface. It uses TextKit 1 on purpose: the block decorations need
/// exact glyph rectangles, which the older layout manager reports reliably.
public final class MilkyTextView: NSTextView {
    var theme = Theme() { didSet { restyle(force: true) } }
    var decorations: [BlockDecoration] = []
    var onLinkActivation: ((String, TokenKind) -> Void)?
    var onTextChange: ((String) -> Void)?

    private var links: [(NSRange, String, TokenKind)] = []
    /// Character index → the glyph to draw there, or nil to draw nothing.
    /// Rebuilt on every restyle and read back by the layout manager delegate.
    private var mathGlyphs: [Int: Character?] = [:]

    /// Where the drawn checkboxes are, so a click can find one. The glyph is
    /// painted rather than typed, so nothing in the text view knows it is there.
    private var checkboxes: [(range: NSRange, done: Bool)] = []
    private var isRestyling = false
    private var restyleWork: DispatchWorkItem?
    private var lastActiveParagraph: NSRange?

    // MARK: - Construction

    public static func make() -> (NSScrollView, MilkyTextView) {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)

        let textView = MilkyTextView(frame: .zero, textContainer: container)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [NSView.AutoresizingMask.width]
        // The caret is a 1px mark: pure lime would be invisible on white.
        textView.insertionPointColor = Ink.accentInk
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.smartInsertDeleteEnabled = false

        // The delegate performs math glyph substitution.
        layout.delegate = textView

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.documentView = textView
        return (scroll, textView)
    }

    // MARK: - Content

    /// Replaces the document wholesale, e.g. when switching notes.
    func load(_ text: String) {
        guard let storage = textStorage else { return }
        isRestyling = true
        storage.setAttributedString(NSAttributedString(string: text,
                                                       attributes: MarkdownStyler.baseAttributes(theme)))
        isRestyling = false
        lastActiveParagraph = nil
        restyle(force: true)
        setSelectedRange(NSRange(location: 0, length: 0))
        scroll(NSPoint(x: 0, y: 0))
    }

    // MARK: - Styling

    func restyle(force: Bool = false) {
        guard let storage = textStorage, !isRestyling else { return }
        // Large documents re-tokenize off the critical path so typing stays smooth.
        if !force, storage.length > 20_000 {
            restyleWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.performRestyle() }
            restyleWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
            return
        }
        performRestyle()
    }

    private func performRestyle() {
        guard let storage = textStorage else { return }
        isRestyling = true
        let selection = selectedRange()
        let active = activeParagraphRange()
        let output = MarkdownStyler.apply(to: storage, theme: theme, activeParagraph: active)
        decorations = output.decorations
        links = output.links
        checkboxes = output.decorations.compactMap { decoration in
            guard case .marker(let range, let glyph) = decoration else { return nil }
            switch glyph {
            case .checkboxOpen: return (range, false)
            case .checkboxDone: return (range, true)
            case .bullet: return nil
            }
        }

        // Glyph generation is cached, so the layout manager has to be told the
        // substitutions changed before it will ask us again.
        if output.mathGlyphs != mathGlyphs || !mathGlyphs.isEmpty {
            mathGlyphs = output.mathGlyphs
            layoutManager?.invalidateGlyphs(forCharacterRange: NSRange(location: 0, length: storage.length),
                                            changeInLength: 0,
                                            actualCharacterRange: nil)
        } else {
            mathGlyphs = output.mathGlyphs
        }
        setSelectedRange(selection)
        typingAttributes = MarkdownStyler.baseAttributes(theme)
        isRestyling = false
        needsDisplay = true
    }

    private func activeParagraphRange() -> NSRange? {
        guard let storage = textStorage, storage.length > 0 else { return nil }
        let selection = selectedRange()
        let location = min(selection.location, storage.length - 1)
        return (storage.string as NSString).paragraphRange(for: NSRange(location: location, length: 0))
    }

    public override func didChangeText() {
        super.didChangeText()
        restyle()
        onTextChange?(string)
    }

    public override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity,
                                           stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        guard !isRestyling, !stillSelecting else { return }
        // Only re-run when the caret actually crosses into a different paragraph,
        // otherwise every arrow key would restyle the document.
        let current = activeParagraphRange()
        if current != lastActiveParagraph {
            lastActiveParagraph = current
            restyle(force: true)
        }
    }

    // MARK: - Block decoration drawing

    public override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let layoutManager, let textContainer else { return }
        let origin = textContainerOrigin

        for decoration in decorations {
            switch decoration {
            case .codeBlock(let range):
                guard let box = boundingBox(range, layoutManager, textContainer, origin) else { continue }
                let inset = box.insetBy(dx: -6, dy: -4).offsetBy(dx: 0, dy: -1)
                let path = NSBezierPath(roundedRect: inset, xRadius: 7, yRadius: 7)
                Ink.codeSurface.setFill()
                path.fill()

            case .quote(let range):
                guard let box = boundingBox(range, layoutManager, textContainer, origin) else { continue }
                let bar = NSRect(x: box.minX + 1, y: box.minY, width: 3, height: box.height)
                let path = NSBezierPath(roundedRect: bar, xRadius: 1.5, yRadius: 1.5)
                Ink.rule.setFill()
                path.fill()

            case .rule(let range):
                guard let box = boundingBox(range, layoutManager, textContainer, origin) else { continue }
                let width = min(textContainer.size.width, bounds.width)
                let line = NSRect(x: box.minX, y: box.midY - 0.5, width: width, height: 1)
                Ink.rule.setFill()
                line.fill()

            case .pill(let range, let style):
                let fill = style == .code ? Ink.codeSurface : Ink.tagSurface
                fill.setFill()
                // A span can wrap across lines, so each line fragment gets its own pill.
                for box in fragmentBoxes(range, layoutManager, textContainer, origin) {
                    let inset = NSRect(x: box.minX - 3, y: box.minY + 1,
                                       width: box.width + 6, height: box.height - 2)
                    let radius: CGFloat = style == .tag ? inset.height / 2 : 4
                    NSBezierPath(roundedRect: inset, xRadius: radius, yRadius: radius).fill()
                }

            case .overline(let range):
                // The bar of a radical. Positioned off the baseline and the font's
                // ascender — a line box is far taller than the glyphs in it, so
                // measuring from its top leaves the bar floating.
                guard let anchor = markerAnchor(range, layoutManager, textContainer, origin),
                      NSMaxRange(range) <= (string as NSString).length else { continue }
                let font = (textStorage?.attribute(.font, at: range.location, effectiveRange: nil)
                            as? NSFont) ?? theme.bodyFont
                Ink.ink.setFill()
                for box in fragmentBoxes(range, layoutManager, textContainer, origin) {
                    let y = anchor.1 - font.ascender * 0.86
                    NSRect(x: box.minX, y: y, width: box.width, height: 1).fill()
                }

            case .marker(let range, let glyph):
                guard let anchor = markerAnchor(range, layoutManager, textContainer, origin) else { continue }
                draw(glyph, at: anchor)
            }
        }
    }

    /// List bullets and checkboxes are drawn over the hidden source characters, so
    /// the file keeps its plain `-` and `[x]` while the page shows real marks.
    private func draw(_ glyph: MarkerGlyph, at anchor: (rect: NSRect, baseline: CGFloat)) {
        let font = theme.bodyFont
        let size = font.pointSize * 0.78
        // Centre on the x-height, not the line box: line-height multiples put extra
        // leading below the glyphs, which would float the marker above the text.
        let centre = NSPoint(x: glyph == .bullet ? anchor.rect.midX : anchor.rect.minX + size / 2,
                             y: anchor.baseline - font.xHeight / 2)

        switch glyph {
        case .bullet:
            let diameter = max(theme.bodySize * 0.30, 4)
            let rect = NSRect(x: centre.x - diameter / 2, y: centre.y - diameter / 2,
                              width: diameter, height: diameter)
            Ink.inkSoft.setFill()
            NSBezierPath(ovalIn: rect).fill()

        case .checkboxOpen:
            let rect = NSRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 0.75, dy: 0.75))
            path.lineWidth = 1.4
            Ink.syntaxActive.setStroke()
            path.stroke()

        case .checkboxDone:
            // A filled disc is exactly what lime is good at.
            let rect = NSRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)
            Ink.accent.setFill()
            NSBezierPath(ovalIn: rect).fill()

            // NSTextView is flipped, so +y runs down: the tick dips before it rises.
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: rect.minX + rect.width * 0.26, y: rect.midY + rect.height * 0.02))
            tick.line(to: NSPoint(x: rect.minX + rect.width * 0.44, y: rect.maxY - rect.height * 0.27))
            tick.line(to: NSPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.29))
            tick.lineWidth = max(1.4, size * 0.13)
            tick.lineCapStyle = .round
            tick.lineJoinStyle = .round
            // On lime the tick has to be dark, not white.
            Ink.onAccent.setStroke()
            tick.stroke()
        }
    }

    /// A marker's rect plus the baseline of the line it sits on.
    private func markerAnchor(_ range: NSRange, _ layoutManager: NSLayoutManager,
                              _ container: NSTextContainer, _ origin: NSPoint) -> (NSRect, CGFloat)? {
        guard range.length > 0, NSMaxRange(range) <= (string as NSString).length else { return nil }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return nil }
        let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let location = layoutManager.location(forGlyphAt: glyphRange.location)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
            .offsetBy(dx: origin.x, dy: origin.y)
        return (rect, fragment.minY + location.y + origin.y)
    }

    /// One rect per line fragment the range covers.
    private func fragmentBoxes(_ range: NSRange, _ layoutManager: NSLayoutManager,
                               _ container: NSTextContainer, _ origin: NSPoint) -> [NSRect] {
        guard range.length > 0, NSMaxRange(range) <= (string as NSString).length else { return [] }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return [] }
        var boxes: [NSRect] = []
        layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange,
                                              withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                              in: container) { rect, _ in
            boxes.append(rect.offsetBy(dx: origin.x, dy: origin.y))
        }
        return boxes
    }

    private func boundingBox(_ range: NSRange, _ layoutManager: NSLayoutManager,
                             _ container: NSTextContainer, _ origin: NSPoint) -> NSRect? {
        guard range.length > 0, NSMaxRange(range) <= (string as NSString).length else { return nil }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return nil }
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
        return rect.offsetBy(dx: origin.x, dy: origin.y)
    }

    // MARK: - Links

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Checkboxes first: the box is drawn over hidden characters, so a hit
        // test on the text would land on the marker and place a caret instead.
        if event.clickCount == 1, let box = checkbox(at: point) {
            toggleTask(in: box.range, currentlyDone: box.done)
            return
        }

        if event.clickCount == 1, let index = characterIndex(at: point),
           let hit = links.first(where: { NSLocationInRange(index, $0.0) }) {
            onLinkActivation?(hit.1, hit.2)
            return
        }
        super.mouseDown(with: event)
    }

    /// Development helper: clicks the first drawn checkbox by computing where it
    /// is on screen and going through `checkbox(at:)`, so it exercises the real
    /// hit test rather than calling the toggle directly.
    @discardableResult
    public func clickFirstCheckbox() -> Bool {
        guard let layoutManager, let textContainer, let first = checkboxes.first,
              let anchor = markerAnchor(first.range, layoutManager, textContainer, textContainerOrigin)
        else { return false }
        let size = theme.bodyFont.pointSize
        let point = NSPoint(x: anchor.0.minX + size * 0.4, y: anchor.1 - size * 0.35)
        guard let box = checkbox(at: point) else { return false }
        toggleTask(in: box.range, currentlyDone: box.done)
        return true
    }

    /// The checkbox under a point, if any. The target is grown a little past the
    /// glyph — a 9pt circle is not a comfortable click target.
    private func checkbox(at point: NSPoint) -> (range: NSRange, done: Bool)? {
        guard let layoutManager, let textContainer else { return nil }
        let origin = textContainerOrigin
        for box in checkboxes {
            guard let anchor = markerAnchor(box.range, layoutManager, textContainer, origin) else { continue }
            let size = theme.bodyFont.pointSize
            let target = NSRect(x: anchor.0.minX - 2,
                                y: anchor.1 - size,
                                width: size * 1.4,
                                height: size * 1.3)
            if target.contains(point) { return box }
        }
        return nil
    }

    /// Flips `[ ]` and `[x]` in the source. Goes through the usual edit path so
    /// it lands on the undo stack like anything else typed.
    private func toggleTask(in markerRange: NSRange, currentlyDone: Bool) {
        let ns = string as NSString
        guard NSMaxRange(markerRange) <= ns.length else { return }
        let boxRange = ns.range(of: "\\[[ xX]\\]", options: .regularExpression, range: markerRange)
        guard boxRange.location != NSNotFound else { return }

        let replacement = currentlyDone ? "[ ]" : "[x]"
        guard shouldChangeText(in: boxRange, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: boxRange, with: replacement)
        didChangeText()
    }

    private func characterIndex(at point: NSPoint) -> Int? {
        guard let layoutManager, let container = textContainer else { return nil }
        let origin = textContainerOrigin
        let local = NSPoint(x: point.x - origin.x, y: point.y - origin.y)
        let glyph = layoutManager.glyphIndex(for: local, in: container,
                                             fractionOfDistanceThroughGlyph: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        guard rect.contains(local) else { return nil }
        return layoutManager.characterIndexForGlyph(at: glyph)
    }

    // MARK: - Markdown-aware editing

    private static let listPrefix = "^(\\s*)([-*+]\\s+(?:\\[[ xX]\\]\\s+)?|\\d+[.)]\\s+|>\\s?)"

    public override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let paragraph = ns.paragraphRange(for: NSRange(location: selectedRange().location, length: 0))
        let line = ns.substring(with: paragraph).trimmingCharacters(in: .newlines)

        guard let match = line.range(of: MilkyTextView.listPrefix, options: .regularExpression) else {
            super.insertNewline(sender)
            return
        }
        let prefix = String(line[match])
        let rest = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Enter on an empty list item ends the list instead of adding another bullet.
        if rest.isEmpty {
            let lineLength = (line as NSString).length
            let replaceRange = NSRange(location: paragraph.location, length: lineLength)
            if shouldChangeText(in: replaceRange, replacementString: "") {
                textStorage?.replaceCharacters(in: replaceRange, with: "")
                didChangeText()
            }
            super.insertNewline(sender)
            return
        }

        super.insertNewline(sender)
        insertText(MilkyTextView.nextPrefix(from: prefix), replacementRange: selectedRange())
    }

    /// Ordered lists increment; everything else repeats, and completed tasks reset to open.
    static func nextPrefix(from prefix: String) -> String {
        if let match = prefix.range(of: "^(\\s*)(\\d+)([.)]\\s+)$", options: .regularExpression) {
            let ns = prefix as NSString
            let re = try! NSRegularExpression(pattern: "^(\\s*)(\\d+)([.)]\\s+)$")
            if let m = re.firstMatch(in: prefix, range: NSRange(location: 0, length: ns.length)),
               let number = Int(ns.substring(with: m.range(at: 2))) {
                return ns.substring(with: m.range(at: 1)) + "\(number + 1)" + ns.substring(with: m.range(at: 3))
            }
            _ = match
        }
        return prefix.replacingOccurrences(of: "[xX]", with: " ", options: .regularExpression)
    }

    public override func insertTab(_ sender: Any?) {
        let ns = string as NSString
        let paragraph = ns.paragraphRange(for: selectedRange())
        let line = ns.substring(with: paragraph)
        if line.range(of: MilkyTextView.listPrefix, options: .regularExpression) != nil {
            insertText("  ", replacementRange: NSRange(location: paragraph.location, length: 0))
            return
        }
        insertText("\t", replacementRange: selectedRange())
    }

    public override func insertBacktab(_ sender: Any?) {
        let ns = string as NSString
        let paragraph = ns.paragraphRange(for: selectedRange())
        let line = ns.substring(with: paragraph)
        for unit in ["  ", "\t"] where line.hasPrefix(unit) {
            let range = NSRange(location: paragraph.location, length: (unit as NSString).length)
            if shouldChangeText(in: range, replacementString: "") {
                textStorage?.replaceCharacters(in: range, with: "")
                didChangeText()
            }
            return
        }
    }

    // MARK: - Formatting commands

    func toggleWrap(_ marker: String) {
        let selection = selectedRange()
        let ns = string as NSString
        guard selection.length > 0 else {
            insertText(marker + marker, replacementRange: selection)
            setSelectedRange(NSRange(location: selection.location + (marker as NSString).length, length: 0))
            return
        }
        let selected = ns.substring(with: selection)
        let markerLength = (marker as NSString).length
        let outer = NSRange(location: selection.location - markerLength,
                            length: selection.length + markerLength * 2)

        // Already wrapped? Unwrap, so the shortcut toggles rather than stacking markers.
        if selected.hasPrefix(marker) && selected.hasSuffix(marker) && selection.length >= markerLength * 2 {
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            replace(selection, with: inner)
            return
        }
        if outer.location >= 0, NSMaxRange(outer) <= ns.length, ns.substring(with: outer).hasPrefix(marker),
           ns.substring(with: outer).hasSuffix(marker) {
            replace(outer, with: selected)
            return
        }
        replace(selection, with: marker + selected + marker)
        setSelectedRange(NSRange(location: selection.location + markerLength, length: selection.length))
    }

    /// Adds or removes a line-leading marker (`# `, `> `, `- `) across the selection.
    func toggleLinePrefix(_ prefix: String) {
        let ns = string as NSString
        let selection = selectedRange()
        let block = ns.paragraphRange(for: selection)
        let lines = ns.substring(with: block).components(separatedBy: "\n")
        let meaningful = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let allPrefixed = !meaningful.isEmpty && meaningful.allSatisfy { $0.hasPrefix(prefix) }

        let rewritten = lines.map { line -> String in
            if line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
            if allPrefixed { return String(line.dropFirst(prefix.count)) }
            // Replace any existing marker of the same family rather than doubling up.
            let stripped = line.replacingOccurrences(of: "^(#{1,6}\\s+|>\\s?|[-*+]\\s+)",
                                                     with: "", options: .regularExpression)
            return prefix + stripped
        }.joined(separator: "\n")

        replace(block, with: rewritten)
    }

    private func replace(_ range: NSRange, with text: String) {
        guard shouldChangeText(in: range, replacementString: text) else { return }
        textStorage?.replaceCharacters(in: range, with: text)
        didChangeText()
    }

    // MARK: - Layout

    public override var textContainerOrigin: NSPoint {
        // Constrain the measure and centre it, so the column stays readable in a wide window.
        let width = min(theme.maxContentWidth, bounds.width - theme.editorHorizontalInset * 2)
        let x = max(theme.editorHorizontalInset, (bounds.width - width) / 2)
        return NSPoint(x: x, y: theme.editorTopInset)
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let width = min(theme.maxContentWidth, newSize.width - theme.editorHorizontalInset * 2)
        textContainer?.size = NSSize(width: max(width, 120), height: CGFloat.greatestFiniteMagnitude)
    }
}
#endif

#if canImport(AppKit)
import CoreText

// MARK: - Math glyph substitution

extension MilkyTextView: NSLayoutManagerDelegate {

    /// Draws `\alpha` as `α` without editing a byte of the file.
    ///
    /// This is the documented way to show something other than the characters in
    /// storage: swap a glyph, and mark the ones it stands in for as `.null` so
    /// they take no space. Selection, copy and save all still see the source —
    /// which is the whole point, since the file must stay what the reader typed.
    public func layoutManager(_ layoutManager: NSLayoutManager,
                              shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                              properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
                              characterIndexes: UnsafePointer<Int>,
                              font: NSFont,
                              forGlyphRange glyphRange: NSRange) -> Int {
        guard !mathGlyphs.isEmpty else { return 0 }

        var newGlyphs = [CGGlyph](repeating: 0, count: glyphRange.length)
        var newProperties = [NSLayoutManager.GlyphProperty](repeating: [], count: glyphRange.length)
        var touched = false

        for i in 0 ..< glyphRange.length {
            newGlyphs[i] = glyphs[i]
            newProperties[i] = properties[i]

            guard let replacement = mathGlyphs[characterIndexes[i]] else { continue }

            guard let character = replacement else {
                // A character the rendering absorbs: `\`, `{`, the letters of a
                // command name. Null glyphs occupy no width.
                newProperties[i] = .null
                touched = true
                continue
            }

            // Only BMP characters can be looked up this way; anything needing a
            // surrogate pair keeps its source glyph rather than drawing wrong.
            let utf16 = Array(String(character).utf16)
            guard utf16.count == 1 else { continue }

            var source = utf16[0]
            var mapped: CGGlyph = 0
            if CTFontGetGlyphsForCharacters(font, &source, &mapped, 1), mapped != 0 {
                newGlyphs[i] = mapped
                touched = true
            }
        }

        guard touched else { return 0 }

        layoutManager.setGlyphs(&newGlyphs,
                                properties: &newProperties,
                                characterIndexes: UnsafeMutablePointer(mutating: characterIndexes),
                                font: font,
                                forGlyphRange: glyphRange)
        return glyphRange.length
    }
}
#endif
