import PDFKit
import SwiftUI

struct DocumentPDFView: NSViewRepresentable {
  let data: Data
  let zoom: Double

  func makeNSView(context: Context) -> PDFView {
    let view = PDFView()
    view.displayMode = .singlePageContinuous
    view.displayDirection = .vertical
    view.backgroundColor = .clear
    return view
  }

  func updateNSView(_ view: PDFView, context: Context) {
    if context.coordinator.data != data {
      context.coordinator.data = data
      view.document = PDFDocument(data: data)
      view.autoScales = true
      context.coordinator.zoom = nil
    }
    if context.coordinator.zoom != zoom {
      let position = view.currentDestination
      view.autoScales = false
      view.scaleFactor = view.scaleFactorForSizeToFit * zoom
      if let position { view.go(to: position) }
      context.coordinator.zoom = zoom
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var data: Data?
    var zoom: Double?
  }
}
