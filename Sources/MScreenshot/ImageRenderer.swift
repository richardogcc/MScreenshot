import AppKit
import CoreImage

/// Draws annotations and renders/encodes the final composited image.
/// All drawing assumes a flipped (top-left origin) graphics context.
enum ImageRenderer {

    // MARK: - Blur precomputation

    static func blurredImage(from image: NSImage) -> NSImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let ci = CIImage(cgImage: cg)
        let scale = CGFloat(cg.width) / max(image.size.width, 1)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(ci.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(14 * scale, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: ci.extent) else { return nil }
        let context = CIContext()
        guard let outCG = context.createCGImage(output, from: ci.extent) else { return nil }
        return NSImage(cgImage: outCG, size: image.size)
    }

    // MARK: - Annotation drawing

    static func draw(_ a: Annotation, imageSize: CGSize, blurred: NSImage?) {
        switch a.tool {
        case .arrow:
            drawArrow(a)
        case .line:
            let path = NSBezierPath()
            path.move(to: a.start)
            path.line(to: a.end)
            stroke(path, a)
        case .rect:
            stroke(NSBezierPath(rect: a.rect), a)
        case .ellipse:
            stroke(NSBezierPath(ovalIn: a.rect), a)
        case .highlight:
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }
            ctx.saveGState()
            ctx.setBlendMode(.multiply)
            a.color.withAlphaComponent(0.4).setFill()
            NSBezierPath(rect: a.rect).fill()
            ctx.restoreGState()
        case .badge:
            drawBadge(a)
        case .text:
            let attributes: [NSAttributedString.Key: Any] = [
                .font: a.font,
                .foregroundColor: a.color,
            ]
            NSAttributedString(string: a.text, attributes: attributes).draw(at: a.start)
        case .blurRect, .blurEllipse, .blurLasso:
            drawBlur(a, imageSize: imageSize, blurred: blurred)
        }
    }

    static func blurClipPath(for a: Annotation) -> NSBezierPath {
        switch a.tool {
        case .blurRect:
            return NSBezierPath(rect: a.rect)
        case .blurEllipse:
            return NSBezierPath(ovalIn: a.rect)
        default:
            let path = NSBezierPath()
            guard let first = a.points.first else { return path }
            path.move(to: first)
            for p in a.points.dropFirst() { path.line(to: p) }
            path.close()
            return path
        }
    }

    private static func drawBlur(_ a: Annotation, imageSize: CGSize, blurred: NSImage?) {
        guard let blurred else { return }
        NSGraphicsContext.current?.saveGraphicsState()
        blurClipPath(for: a).addClip()
        blurred.draw(in: CGRect(origin: .zero, size: imageSize),
                     from: .zero, operation: .sourceOver, fraction: 1,
                     respectFlipped: true, hints: nil)
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private static func drawArrow(_ a: Annotation) {
        let dx = a.end.x - a.start.x
        let dy = a.end.y - a.start.y
        guard dx != 0 || dy != 0 else { return }
        let angle = atan2(dy, dx)
        let headLength = max(14, a.lineWidth * 3.8)
        // Shorten the shaft so it doesn't poke through the head.
        let shaftEnd = CGPoint(x: a.end.x - headLength * 0.6 * cos(angle),
                               y: a.end.y - headLength * 0.6 * sin(angle))
        let path = NSBezierPath()
        path.move(to: a.start)
        path.line(to: shaftEnd)
        stroke(path, a)

        let head = NSBezierPath()
        head.move(to: a.end)
        head.line(to: CGPoint(x: a.end.x - headLength * cos(angle - 0.42),
                              y: a.end.y - headLength * sin(angle - 0.42)))
        head.line(to: CGPoint(x: a.end.x - headLength * cos(angle + 0.42),
                              y: a.end.y - headLength * sin(angle + 0.42)))
        head.close()
        a.color.setFill()
        head.fill()
    }

    private static func drawBadge(_ a: Annotation) {
        let diameter = 20 + a.lineWidth * 3.5
        let rect = CGRect(x: a.start.x - diameter / 2, y: a.start.y - diameter / 2,
                          width: diameter, height: diameter)
        a.color.setFill()
        NSBezierPath(ovalIn: rect).fill()

        let text = "\(a.badgeNumber)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: diameter * 0.55),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                  withAttributes: attributes)
    }

    private static func stroke(_ path: NSBezierPath, _ a: Annotation) {
        path.lineWidth = a.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        a.color.setStroke()
        path.stroke()
    }

    // MARK: - Final rendering

    /// Composites base image + annotations into a bitmap at the base
    /// image's full pixel resolution.
    static func render(base: NSImage, annotations: [Annotation]) -> NSBitmapImageRep? {
        guard let cg = base.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let pixelsWide = cg.width
        let pixelsHigh = cg.height
        guard pixelsWide > 0, pixelsHigh > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: pixelsWide,
                                         pixelsHigh: pixelsHigh,
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .calibratedRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0),
              let bitmapContext = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        rep.size = base.size
        NSGraphicsContext.saveGraphicsState()
        let cgContext = bitmapContext.cgContext
        // Flip to a top-left origin and scale points -> pixels so the same
        // drawing code used on screen works here.
        cgContext.translateBy(x: 0, y: CGFloat(pixelsHigh))
        cgContext.scaleBy(x: CGFloat(pixelsWide) / base.size.width,
                          y: -CGFloat(pixelsHigh) / base.size.height)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: true)

        let bounds = CGRect(origin: .zero, size: base.size)
        base.draw(in: bounds, from: .zero, operation: .copy, fraction: 1,
                  respectFlipped: true, hints: nil)
        let blurred = annotations.contains(where: { $0.tool.isBlur }) ? blurredImage(from: base) : nil
        for annotation in annotations {
            draw(annotation, imageSize: base.size, blurred: blurred)
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    static func encode(base: NSImage, annotations: [Annotation], format: ImageFormat) -> Data? {
        guard let rep = render(base: base, annotations: annotations) else { return nil }
        let properties: [NSBitmapImageRep.PropertyKey: Any] =
            format == .jpeg ? [.compressionFactor: 0.9] : [:]
        return rep.representation(using: format.fileType, properties: properties)
    }
}
