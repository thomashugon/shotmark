import SwiftUI

enum Tool: String, CaseIterable, Identifiable {
    case rectangle, ellipse, line, arrow, freehand, text, highlight, obfuscate, counter, crop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .line: return "Ligne"
        case .arrow: return "Flèche"
        case .freehand: return "Main levée"
        case .text: return "Texte"
        case .highlight: return "Surligner"
        case .obfuscate: return "Flouter"
        case .counter: return "Numéro"
        case .crop: return "Recadrer"
        }
    }

    var symbol: String {
        switch self {
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .freehand: return "scribble"
        case .text: return "textformat"
        case .highlight: return "highlighter"
        case .obfuscate: return "mosaic"
        case .counter: return "1.circle"
        case .crop: return "crop"
        }
    }

    /// Single-key shortcut, like Greenshot's editor.
    var shortcut: KeyEquivalent {
        switch self {
        case .rectangle: return "r"
        case .ellipse: return "e"
        case .line: return "l"
        case .arrow: return "a"
        case .freehand: return "f"
        case .text: return "t"
        case .highlight: return "h"
        case .obfuscate: return "o"
        case .counter: return "i"
        case .crop: return "c"
        }
    }
}

struct Annotation: Identifiable {
    let id = UUID()
    var tool: Tool
    var start: CGPoint
    var end: CGPoint
    var points: [CGPoint] = []
    var color: Color
    var lineWidth: CGFloat
    var text: String = ""
    var number: Int = 0

    var rect: CGRect {
        CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
               width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    func offsetBy(dx: CGFloat, dy: CGFloat) -> Annotation {
        var copy = self
        copy.start = CGPoint(x: start.x + dx, y: start.y + dy)
        copy.end = CGPoint(x: end.x + dx, y: end.y + dy)
        copy.points = points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        return copy
    }
}
