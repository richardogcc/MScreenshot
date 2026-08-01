#!/usr/bin/env swift
// Generates Resources/AppIcon.icns (and docs/icon.png) programmatically.
// Usage: swift scripts/make_icon.swift

import AppKit

func drawIcon(pixelSize: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let s = CGFloat(pixelSize)
    // macOS icons keep a transparent margin around the rounded square.
    let inset = s * 0.09
    let squareRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = squareRect.width * 0.225

    let background = NSBezierPath(roundedRect: squareRect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.29, green: 0.56, blue: 0.89, alpha: 1),
                              ending: NSColor(calibratedRed: 0.48, green: 0.29, blue: 0.87, alpha: 1))!
    gradient.draw(in: background, angle: -60)

    // Viewfinder corner brackets.
    NSColor.white.setStroke()
    let bracket = squareRect.insetBy(dx: squareRect.width * 0.18, dy: squareRect.height * 0.18)
    let len = squareRect.width * 0.14
    let lineWidth = max(1, squareRect.width * 0.055)
    let corners: [(CGPoint, CGFloat, CGFloat)] = [
        (CGPoint(x: bracket.minX, y: bracket.minY), 1, 1),
        (CGPoint(x: bracket.maxX, y: bracket.minY), -1, 1),
        (CGPoint(x: bracket.minX, y: bracket.maxY), 1, -1),
        (CGPoint(x: bracket.maxX, y: bracket.maxY), -1, -1),
    ]
    for (corner, dx, dy) in corners {
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.move(to: CGPoint(x: corner.x + dx * len, y: corner.y))
        path.line(to: corner)
        path.line(to: CGPoint(x: corner.x, y: corner.y + dy * len))
        path.stroke()
    }

    // Lens ring + inner dot.
    let ringRadius = squareRect.width * 0.155
    let center = CGPoint(x: squareRect.midX, y: squareRect.midY)
    let ring = NSBezierPath(ovalIn: CGRect(x: center.x - ringRadius, y: center.y - ringRadius,
                                           width: ringRadius * 2, height: ringRadius * 2))
    ring.lineWidth = lineWidth
    ring.stroke()
    let dotRadius = ringRadius * 0.45
    NSColor.white.setFill()
    NSBezierPath(ovalIn: CGRect(x: center.x - dotRadius, y: center.y - dotRadius,
                                width: dotRadius * 2, height: dotRadius * 2)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) {
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset", isDirectory: true)
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in entries {
    writePNG(drawIcon(pixelSize: size), to: iconset.appendingPathComponent("\(name).png"))
}

try? fm.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
writePNG(drawIcon(pixelSize: 256), to: root.appendingPathComponent("docs/icon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "AppIcon.icns generated" : "iconutil failed")
