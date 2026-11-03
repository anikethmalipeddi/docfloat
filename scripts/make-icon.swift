import AppKit
import Foundation

// Vector-drawn artwork, rendered at every macOS icon size.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = root.appendingPathComponent("DocFloat.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = size * scale
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
                            xRadius: 205, yRadius: 205)
    NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.37, blue: 0.95, alpha: 1),
               ending: NSColor(calibratedRed: 0.37, green: 0.20, blue: 0.83, alpha: 1))!
      .draw(in: tile, angle: -65)

    NSColor.white.withAlphaComponent(0.22).setFill()
    NSBezierPath(roundedRect: NSRect(x: 220, y: 310, width: 460, height: 490),
                 xRadius: 65, yRadius: 65).fill()
    NSColor.white.withAlphaComponent(0.35).setStroke()
    let back = NSBezierPath(roundedRect: NSRect(x: 220, y: 310, width: 460, height: 490),
                            xRadius: 65, yRadius: 65)
    back.lineWidth = 7
    back.stroke()

    let note = NSBezierPath(roundedRect: NSRect(x: 350, y: 220, width: 460, height: 490),
                            xRadius: 65, yRadius: 65)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor.white.withAlphaComponent(0.95).setFill()
    note.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedRed: 0.32, green: 0.34, blue: 0.78, alpha: 1).setFill()
    for (y, width) in [(570.0, 260.0), (475.0, 260.0), (380.0, 170.0)] {
      NSBezierPath(roundedRect: NSRect(x: 445, y: y, width: width, height: 28),
                   xRadius: 14, yRadius: 14).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    let file = iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: file)
  }
}
