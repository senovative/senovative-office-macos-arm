import AppKit
import Foundation

struct IconSlot {
    let pointSize: Int
    let scale: Int

    var pixelSize: Int {
        pointSize * scale
    }

    var filename: String {
        "app-icon-\(pointSize)@\(scale)x.png"
    }
}

let slots = [
    IconSlot(pointSize: 16, scale: 1),
    IconSlot(pointSize: 16, scale: 2),
    IconSlot(pointSize: 32, scale: 1),
    IconSlot(pointSize: 32, scale: 2),
    IconSlot(pointSize: 128, scale: 1),
    IconSlot(pointSize: 128, scale: 2),
    IconSlot(pointSize: 256, scale: 1),
    IconSlot(pointSize: 256, scale: 2),
    IconSlot(pointSize: 512, scale: 1),
    IconSlot(pointSize: 512, scale: 2),
]

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift Tools/generate-placeholder-icon.swift <AppIcon.appiconset>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for slot in slots {
    let side = slot.pixelSize
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side,
            pixelsHigh: side,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else {
        fputs("Failed to create bitmap for \(slot.filename)\n", stderr)
        exit(1)
    }

    bitmap.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let bounds = NSRect(x: 0, y: 0, width: side, height: side)
    NSColor(red: 0.0, green: 0.36, blue: 0.74, alpha: 1).setFill()
    NSBezierPath(roundedRect: bounds, xRadius: CGFloat(side) * 0.18, yRadius: CGFloat(side) * 0.18).fill()

    NSColor.white.setStroke()
    let inset = CGFloat(side) * 0.18
    let pageRect = NSRect(x: inset, y: inset * 0.8, width: CGFloat(side) - inset * 2, height: CGFloat(side) - inset * 1.6)
    let pagePath = NSBezierPath(roundedRect: pageRect, xRadius: CGFloat(side) * 0.035, yRadius: CGFloat(side) * 0.035)
    pagePath.lineWidth = max(1, CGFloat(side) * 0.035)
    pagePath.stroke()

    let paragraphLineWidth = max(1, CGFloat(side) * 0.028)
    for index in 0..<4 {
        let y = pageRect.maxY - CGFloat(index + 1) * pageRect.height * 0.18
        let line = NSBezierPath()
        line.move(to: NSPoint(x: pageRect.minX + pageRect.width * 0.18, y: y))
        line.line(to: NSPoint(x: pageRect.maxX - pageRect.width * (index == 3 ? 0.34 : 0.18), y: y))
        line.lineWidth = paragraphLineWidth
        line.lineCapStyle = .round
        line.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Failed to render \(slot.filename)\n", stderr)
        exit(1)
    }

    try png.write(to: outputDirectory.appendingPathComponent(slot.filename))
}
