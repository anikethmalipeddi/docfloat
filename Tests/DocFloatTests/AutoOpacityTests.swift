import Foundation
import Testing

@testable import DocFloat

@Test func automaticOpacityDependsOnBothDocumentAndBackground() {
  let document = ReadingContrast(dark: 0, light: 1)
  let white = AutoOpacity.recommendation(document: document, background: [1])
  let black = AutoOpacity.recommendation(document: document, background: [0])
  #expect(white != black)
  #expect(white > 0 && white < 1)
  #expect(black > 0 && black < 1)
  let faintDocument = ReadingContrast(dark: 0.25, light: 0.9)
  #expect(AutoOpacity.recommendation(document: faintDocument, background: [1]) > white)
}

@Test func busyBackgroundAddsReadabilityMargin() {
  let document = ReadingContrast.standard
  let white = AutoOpacity.recommendation(document: document, background: [1, 1])
  let busy = AutoOpacity.recommendation(document: document, background: [0, 1])
  #expect(busy >= white)
  #expect(busy <= 1)
}

@MainActor @Test func manualOpacityHasNoFloorAndHiddenWindowCanBeRecovered() {
  let model = AppModel()
  let previousOpacity = model.opacity
  let previousAuto = model.adaptiveContrast
  defer {
    model.opacity = previousOpacity
    model.adaptiveContrast = previousAuto
  }
  model.setManualOpacity(0)
  #expect(model.opacity == 0)
  #expect(!model.adaptiveContrast)
  model.showWindow()
  #expect(model.opacity > 0)
}
