// SPDX-License-Identifier: GPL-3.0-only
// Draws the application icon and writes it as an .iconset directory.
//
// Usage: swift scripts/make-icon.swift <output.iconset>
// Then:  iconutil -c icns <output.iconset> -o Resources/AppIcon.icns
//
// The icon is a gradient tile with a keyboard and one hint label, the two things the app is about.

import AppKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift make-icon.swift <output.iconset>\n".utf8))
    exit(64)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// Draws the icon into a square of `side` pixels. All measurements are fractions of a 1024 grid.
func drawIcon(side: CGFloat) {
    let unit = side / 1024
    func scaled(_ value: CGFloat) -> CGFloat { value * unit }

    // The tile follows the macOS icon grid: 824 of 1024, leaving room for the shadow.
    let tile = NSRect(x: scaled(100), y: scaled(100), width: scaled(824), height: scaled(824))
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: scaled(186), yRadius: scaled(186))

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = scaled(28)
    shadow.shadowOffset = NSSize(width: 0, height: -scaled(12))
    shadow.set()
    NSColor.black.setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(srgbRed: 0.23, green: 0.51, blue: 0.96, alpha: 1),
        NSColor(srgbRed: 0.55, green: 0.36, blue: 0.96, alpha: 1),
        NSColor(srgbRed: 0.93, green: 0.28, blue: 0.60, alpha: 1),
    ])?.draw(in: tilePath, angle: -45)

    // A soft highlight across the top half gives the tile some depth.
    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])?
        .draw(in: NSRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // The keyboard: a white body with three rows of keys cut out in the tile's colours.
    let body = NSRect(x: scaled(232), y: scaled(318), width: scaled(560), height: scaled(350))
    NSColor.white.setFill()
    NSBezierPath(roundedRect: body, xRadius: scaled(64), yRadius: scaled(64)).fill()

    let keyColor = NSColor(srgbRed: 0.42, green: 0.40, blue: 0.95, alpha: 1)
    keyColor.setFill()
    let keySize = scaled(62), gap = scaled(26)
    for row in 0..<2 {
        let count = 5
        let rowWidth = CGFloat(count) * keySize + CGFloat(count - 1) * gap
        let originX = body.midX - rowWidth / 2
        let originY = body.maxY - scaled(58) - keySize - CGFloat(row) * (keySize + gap)
        for column in 0..<count {
            let key = NSRect(x: originX + CGFloat(column) * (keySize + gap), y: originY, width: keySize, height: keySize)
            NSBezierPath(roundedRect: key, xRadius: scaled(16), yRadius: scaled(16)).fill()
        }
    }
    let spaceBar = NSRect(x: body.midX - scaled(150), y: body.minY + scaled(52), width: scaled(300), height: scaled(54))
    NSBezierPath(roundedRect: spaceBar, xRadius: scaled(18), yRadius: scaled(18)).fill()

    // One hint label, the way the app draws them over a button.
    let label = NSRect(x: scaled(590), y: scaled(590), width: scaled(250), height: scaled(190))
    let labelPath = NSBezierPath(roundedRect: label, xRadius: scaled(52), yRadius: scaled(52))
    NSGraphicsContext.saveGraphicsState()
    let labelShadow = NSShadow()
    labelShadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    labelShadow.shadowBlurRadius = scaled(18)
    labelShadow.shadowOffset = NSSize(width: 0, height: -scaled(8))
    labelShadow.set()
    NSColor(srgbRed: 1.0, green: 0.80, blue: 0.22, alpha: 1).setFill()
    labelPath.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.9).setStroke()
    labelPath.lineWidth = scaled(10)
    labelPath.stroke()

    let text = NSAttributedString(
        string: "F",
        attributes: [
            .font: NSFont.systemFont(ofSize: scaled(140), weight: .heavy),
            .foregroundColor: NSColor(srgbRed: 0.16, green: 0.14, blue: 0.22, alpha: 1),
        ]
    )
    let textSize = text.size()
    text.draw(at: NSPoint(x: label.midX - textSize.width / 2, y: label.midY - textSize.height / 2))
}

func writePNG(pixels: Int, name: String) throws {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(side: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: output.appendingPathComponent(name))
}

// The sizes iconutil expects: each point size at 1x and 2x.
for points in [16, 32, 128, 256, 512] {
    try writePNG(pixels: points, name: "icon_\(points)x\(points).png")
    try writePNG(pixels: points * 2, name: "icon_\(points)x\(points)@2x.png")
}
