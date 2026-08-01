import AppKit

enum Tool: Int, CaseIterable {
    case arrow
    case line
    case rect
    case ellipse
    case highlight
    case badge
    case text
    case blurRect
    case blurEllipse
    case blurLasso

    var isBlur: Bool {
        switch self {
        case .blurRect, .blurEllipse, .blurLasso: return true
        default: return false
        }
    }
}

/// One drawn element on top of the screenshot. Coordinates are in image
/// points with a top-left origin (flipped), matching `CanvasView`.
struct Annotation {
    var tool: Tool
    var start: CGPoint = .zero
    var end: CGPoint = .zero
    var points: [CGPoint] = []
    var color: NSColor = .systemRed
    var lineWidth: CGFloat = 4
    var text: String = ""
    var font: NSFont = .systemFont(ofSize: 28)
    var badgeNumber: Int = 1

    var rect: CGRect {
        CGRect(x: min(start.x, end.x),
               y: min(start.y, end.y),
               width: abs(end.x - start.x),
               height: abs(end.y - start.y))
    }
}
