import AppKit
@preconcurrency import ScreenCaptureKit

struct ReadingContrast: Equatable, Sendable {
  let dark: Double
  let light: Double
  static let standard = ReadingContrast(dark: 0.05, light: 0.98)
}

enum AutoOpacity {
  static func pixels(_ image: CGImage) -> [Double] {
    let side = 64
    var bytes = [UInt8](repeating: 0, count: side * side * 4)
    let drawn = bytes.withUnsafeMutableBytes { memory -> Bool in
      guard
        let context = CGContext(
          data: memory.baseAddress, width: side, height: side,
          bitsPerComponent: 8, bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
      return true
    }
    guard drawn else { return [] }
    return stride(from: 0, to: bytes.count, by: 4).map { offset -> Double in
      let red = Double(bytes[offset]) * 0.2126
      let green = Double(bytes[offset + 1]) * 0.7152
      let blue = Double(bytes[offset + 2]) * 0.0722
      return (red + green + blue) / 255.0
    }
  }

  static func document(_ image: CGImage) -> ReadingContrast {
    let values = pixels(image).sorted()
    guard let low = values.first, let high = values.last, high - low > 0.25 else {
      return .standard
    }
    return ReadingContrast(dark: low, light: high)
  }

  // Find an alpha meeting a 7:1 text contrast target over sampled backgrounds.
  // Busy backgrounds add a small margin to reduce interference from underlying text.
  static func recommendation(document: ReadingContrast, background: [Double]) -> Double {
    guard !background.isEmpty else { return 0.8 }
    func linear(_ value: Double) -> Double {
      value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    let mean = background.reduce(0, +) / Double(background.count)
    let variance = background.reduce(0) { $0 + pow($1 - mean, 2) } / Double(background.count)
    let margin = min(0.18, 0.06 + sqrt(variance) * 0.5)
    for step in 0...100 {
      let alpha = Double(step) / 100
      let readable = background.allSatisfy { behind in
        let dark = linear(document.dark * alpha + behind * (1 - alpha))
        let light = linear(document.light * alpha + behind * (1 - alpha))
        return (light + 0.05) / (dark + 0.05) >= 7
      }
      if readable { return min(1, alpha + margin) }
    }
    return 1
  }

  @MainActor static func background(behind window: NSWindow) async throws -> [Double] {
    let available = try await SCShareableContent.excludingDesktopWindows(
      false, onScreenWindowsOnly: true)
    guard let screen = window.screen,
      let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
      let display = available.displays.first(where: { $0.displayID == number.uint32Value })
    else {
      throw NSError(domain: "DocFloat.Contrast", code: 1)
    }
    let ownApps = available.applications.filter {
      $0.processID == ProcessInfo.processInfo.processIdentifier
    }
    guard !ownApps.isEmpty else { throw NSError(domain: "DocFloat.Contrast", code: 2) }
    let filter = SCContentFilter(
      display: display, excludingApplications: ownApps, exceptingWindows: [])
    let visible = window.frame.intersection(screen.frame)
    guard !visible.isEmpty else { throw NSError(domain: "DocFloat.Contrast", code: 3) }
    let config = SCStreamConfiguration()
    config.sourceRect = CGRect(
      x: visible.minX - screen.frame.minX,
      y: screen.frame.maxY - visible.maxY, width: visible.width, height: visible.height)
    config.width = 64
    config.height = 64
    config.showsCursor = false
    let image = try await SCScreenshotManager.captureImage(
      contentFilter: filter, configuration: config)
    return pixels(image)
  }
}
