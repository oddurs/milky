import Foundation

/// Where a character sits relative to the baseline.
public enum MathRaise: Equatable, Sendable { case none, superscript, `subscript` }

public struct MathStyle: Equatable, Sendable {
    /// TeX sets single-letter variables in italic and everything else upright.
    public var italic: Bool = false
    /// 0 is the base line, 1 a script, 2 a script of a script. Each level shrinks.
    public var scriptDepth: Int = 0
    public var raise: MathRaise = .none
    /// Drawn with a rule above it — the bar of a radical.
    public var overline: Bool = false

    public init(italic: Bool = false, scriptDepth: Int = 0,
                raise: MathRaise = .none, overline: Bool = false) {
        self.italic = italic
        self.scriptDepth = scriptDepth
        self.raise = raise
        self.overline = overline
    }
}

/// One entry per *source* character, which is what lets the editor substitute
/// glyphs without touching the file: `\alpha` is six characters that draw as one
/// `α` and five nothings.
public struct MathCharacter: Equatable, Sendable {
    /// The character to draw, or nil to draw nothing at all.
    public var display: Character?
    public var style: MathStyle

    public init(display: Character?, style: MathStyle = MathStyle()) {
        self.display = display
        self.style = style
    }
}

/// A typesetter for the subset of TeX that people actually write in notes.
///
/// Not KaTeX, and deliberately so: KaTeX is JavaScript, and running it would mean
/// a web view per formula inside an `NSTextView`. This produces plain attributes
/// and glyph substitutions instead, so math lives in the same text storage as
/// everything else — it selects, copies and saves as the source you typed.
///
/// What it does not do is stack: `\frac{a}{b}` draws as `a⁄b` rather than as a
/// true two-level fraction, because a stacked fraction needs its own line layout.
/// For notes, that trade is worth making.
public enum MathRenderer {

    // MARK: - Symbols

    /// Commands that stand for a single character. Kept to what turns up in real
    /// notes rather than the whole of `symbols.pdf`.
    public static let symbols: [String: Character] = [
        // Greek, lower
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε",
        "varepsilon": "ε", "zeta": "ζ", "eta": "η", "theta": "θ", "vartheta": "ϑ",
        "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ",
        "pi": "π", "rho": "ρ", "sigma": "σ", "tau": "τ", "upsilon": "υ",
        "phi": "φ", "varphi": "ϕ", "chi": "χ", "psi": "ψ", "omega": "ω",
        // Greek, upper
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ",
        "Pi": "Π", "Sigma": "Σ", "Upsilon": "Υ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
        // Operators
        "times": "×", "div": "÷", "pm": "±", "mp": "∓", "cdot": "⋅", "ast": "∗",
        "star": "⋆", "circ": "∘", "bullet": "∙", "oplus": "⊕", "otimes": "⊗",
        // Relations
        "leq": "≤", "le": "≤", "geq": "≥", "ge": "≥", "neq": "≠", "ne": "≠",
        "approx": "≈", "equiv": "≡", "sim": "∼", "simeq": "≃", "cong": "≅",
        "propto": "∝", "ll": "≪", "gg": "≫",
        // Sets and logic
        "in": "∈", "notin": "∉", "ni": "∋", "subset": "⊂", "subseteq": "⊆",
        "supset": "⊃", "supseteq": "⊇", "cup": "∪", "cap": "∩", "setminus": "∖",
        "emptyset": "∅", "varnothing": "∅", "forall": "∀", "exists": "∃",
        "nexists": "∄", "neg": "¬", "land": "∧", "lor": "∨", "therefore": "∴",
        "because": "∵",
        // Big operators
        "sum": "∑", "prod": "∏", "coprod": "∐", "int": "∫", "iint": "∬",
        "oint": "∮", "bigcup": "⋃", "bigcap": "⋂",
        // Arrows
        "to": "→", "rightarrow": "→", "leftarrow": "←", "leftrightarrow": "↔",
        "Rightarrow": "⇒", "Leftarrow": "⇐", "Leftrightarrow": "⇔",
        "mapsto": "↦", "uparrow": "↑", "downarrow": "↓",
        // Misc
        "infty": "∞", "partial": "∂", "nabla": "∇", "surd": "√", "angle": "∠",
        "degree": "°", "prime": "′", "ldots": "…", "cdots": "⋯", "vdots": "⋮",
        "aleph": "ℵ", "hbar": "ℏ", "ell": "ℓ", "Re": "ℜ", "Im": "ℑ",
        "perp": "⊥", "parallel": "∥", "top": "⊤", "bot": "⊥",
        // Blackboard bold, the ones anyone writes
        "mathbbR": "ℝ", "mathbbN": "ℕ", "mathbbZ": "ℤ", "mathbbQ": "ℚ",
        "mathbbC": "ℂ", "mathbbP": "ℙ", "mathbbE": "𝔼",
    ]

    /// Multi-letter names that are set upright, per TeX convention.
    static let functions: Set<String> = [
        "arccos", "arcsin", "arctan", "arg", "cos", "cosh", "cot", "coth", "csc",
        "deg", "det", "dim", "exp", "gcd", "hom", "inf", "ker", "lg", "lim",
        "liminf", "limsup", "ln", "log", "max", "min", "Pr", "sec", "sin", "sinh",
        "sup", "tan", "tanh",
    ]

    // MARK: - Rendering

    /// Returns exactly one entry per character of `source`, so a caller can map
    /// results straight onto character indexes.
    public static func render(_ source: String) -> [MathCharacter] {
        let chars = Array(source)
        var out = [MathCharacter](repeating: MathCharacter(display: nil), count: chars.count)
        var style = MathStyle()
        // `{ … }` restores the enclosing style when it closes.
        var groupStack: [MathStyle] = []
        var i = 0

        func emit(_ index: Int, _ display: Character?, italic: Bool = false) {
            var s = style
            s.italic = italic
            out[index] = MathCharacter(display: display, style: s)
        }

        while i < chars.count {
            let c = chars[i]

            switch c {
            case "\\":
                let start = i
                var j = i + 1
                while j < chars.count, chars[j].isLetter { j += 1 }
                let name = String(chars[(i + 1)..<j])

                if name.isEmpty {
                    // An escaped delimiter: \$ \{ \} \\
                    if j < chars.count {
                        emit(start, nil)
                        emit(j, chars[j])
                        i = j + 1
                    } else {
                        emit(start, "\\")
                        i = j
                    }
                    continue
                }

                // \mathbb{R} and friends collapse to one blackboard character.
                if name == "mathbb", j < chars.count, chars[j] == "{",
                   j + 2 < chars.count, chars[j + 2] == "}",
                   let symbol = symbols["mathbb\(chars[j + 1])"] {
                    emit(start, symbol)
                    for k in (start + 1)...(j + 2) { emit(k, nil) }
                    i = j + 3
                    continue
                }

                if name == "frac" || name == "dfrac" || name == "tfrac" {
                    i = renderFraction(chars, from: start, nameEnd: j, style: style, into: &out)
                    continue
                }

                if name == "sqrt" {
                    i = renderRadical(chars, from: start, nameEnd: j, style: style, into: &out)
                    continue
                }

                if let symbol = symbols[name] {
                    emit(start, symbol)
                    for k in (start + 1)..<j { emit(k, nil) }
                    i = j
                    continue
                }

                if functions.contains(name) {
                    emit(start, nil)
                    for (offset, ch) in name.enumerated() { emit(start + 1 + offset, ch) }
                    i = j
                    continue
                }

                // Unknown command: show it as written rather than swallowing it.
                emit(start, "\\")
                for (offset, ch) in name.enumerated() { emit(start + 1 + offset, ch, italic: false) }
                i = j

            case "^", "_":
                let raise: MathRaise = (c == "^") ? .superscript : .subscript
                emit(i, nil)
                i = applyScript(chars, from: i + 1, raise: raise, style: style, into: &out)

            case "{":
                emit(i, nil)
                groupStack.append(style)
                i += 1

            case "}":
                emit(i, nil)
                if let restored = groupStack.popLast() { style = restored }
                i += 1

            case " ":
                // TeX collapses spacing, but a note reads better keeping it.
                emit(i, " ")
                i += 1

            default:
                // Single letters are variables and set italic; digits and
                // operators stay upright.
                emit(i, c, italic: c.isLetter)
                i += 1
            }
        }
        return out
    }

    // MARK: - Structures

    /// `^{…}` or `^x`. Returns the index just past whatever the script covered.
    private static func applyScript(_ chars: [Character], from start: Int, raise: MathRaise,
                                    style: MathStyle, into out: inout [MathCharacter]) -> Int {
        guard start < chars.count else { return start }
        var inner = style
        inner.raise = raise
        inner.scriptDepth = min(style.scriptDepth + 1, 2)

        if chars[start] == "{" {
            guard let close = matchingBrace(chars, open: start) else { return start }
            out[start] = MathCharacter(display: nil, style: inner)
            let body = String(chars[(start + 1)..<close])
            for (offset, rendered) in render(body).enumerated() {
                var merged = rendered
                merged.style.raise = raise
                merged.style.scriptDepth = min(rendered.style.scriptDepth + inner.scriptDepth, 2)
                out[start + 1 + offset] = merged
            }
            out[close] = MathCharacter(display: nil, style: inner)
            return close + 1
        }

        // `^\infty` — the script body is a whole command, not one character.
        if chars[start] == "\\" {
            var end = start + 1
            while end < chars.count, chars[end].isLetter { end += 1 }
            let rendered = render(String(chars[start..<end]))
            for (offset, var item) in rendered.enumerated() {
                item.style.raise = raise
                item.style.scriptDepth = min(item.style.scriptDepth + inner.scriptDepth, 2)
                out[start + offset] = item
            }
            return end
        }

        var single = inner
        single.italic = chars[start].isLetter
        out[start] = MathCharacter(display: chars[start], style: single)
        return start + 1
    }

    /// `\frac{a}{b}` → `a⁄b`. Not stacked; see the note on the type.
    private static func renderFraction(_ chars: [Character], from start: Int, nameEnd: Int,
                                       style: MathStyle, into out: inout [MathCharacter]) -> Int {
        for k in start..<nameEnd { out[k] = MathCharacter(display: nil, style: style) }
        guard nameEnd < chars.count, chars[nameEnd] == "{",
              let firstClose = matchingBrace(chars, open: nameEnd),
              firstClose + 1 < chars.count, chars[firstClose + 1] == "{",
              let secondClose = matchingBrace(chars, open: firstClose + 1)
        else { return nameEnd }

        copy(chars, body: (nameEnd + 1)..<firstClose, style: style, into: &out)
        out[nameEnd] = MathCharacter(display: nil, style: style)
        // The closing brace of the numerator carries the fraction slash.
        out[firstClose] = MathCharacter(display: "\u{2044}", style: style)
        out[firstClose + 1] = MathCharacter(display: nil, style: style)
        copy(chars, body: (firstClose + 2)..<secondClose, style: style, into: &out)
        out[secondClose] = MathCharacter(display: nil, style: style)
        return secondClose + 1
    }

    /// `\sqrt{x}` → `√x` with the radicand overlined, which the editor draws.
    private static func renderRadical(_ chars: [Character], from start: Int, nameEnd: Int,
                                      style: MathStyle, into out: inout [MathCharacter]) -> Int {
        out[start] = MathCharacter(display: "√", style: style)
        for k in (start + 1)..<nameEnd { out[k] = MathCharacter(display: nil, style: style) }
        guard nameEnd < chars.count, chars[nameEnd] == "{",
              let close = matchingBrace(chars, open: nameEnd)
        else { return nameEnd }

        out[nameEnd] = MathCharacter(display: nil, style: style)
        var barred = style
        barred.overline = true
        copy(chars, body: (nameEnd + 1)..<close, style: barred, into: &out)
        out[close] = MathCharacter(display: nil, style: style)
        return close + 1
    }

    /// Renders a nested body and merges the enclosing style into it.
    private static func copy(_ chars: [Character], body: Range<Int>, style: MathStyle,
                             into out: inout [MathCharacter]) {
        guard !body.isEmpty else { return }
        let rendered = render(String(chars[body]))
        for (offset, var item) in rendered.enumerated() {
            item.style.scriptDepth = min(item.style.scriptDepth + style.scriptDepth, 2)
            if style.raise != .none { item.style.raise = style.raise }
            if style.overline { item.style.overline = true }
            out[body.lowerBound + offset] = item
        }
    }

    static func matchingBrace(_ chars: [Character], open: Int) -> Int? {
        var depth = 0
        var i = open
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    /// The plain-text form, for search indexes and note snippets.
    public static func plainText(_ source: String) -> String {
        String(render(source).compactMap(\.display))
    }
}
