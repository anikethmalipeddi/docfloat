import PDFKit
import SwiftUI

struct DocumentPDFView: NSViewRepresentable {
  let data: Data
  let zoom: Double
  let query: String
  let step: Int
  let backward: Bool
  let onFind: (String) -> Void

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
      context.coordinator.query = nil
    }
    if context.coordinator.zoom != zoom {
      let position = view.currentDestination
      view.autoScales = false
      view.scaleFactor = view.scaleFactorForSizeToFit * zoom
      if let position { view.go(to: position) }
      context.coordinator.zoom = zoom
    }
    let coordinator = context.coordinator
    let changed = coordinator.query != query || coordinator.step != step
    guard changed else { return }
    if coordinator.query != query {
      coordinator.query = query
      coordinator.matches =
        query.isEmpty ? [] : (view.document?.findString(query, withOptions: .caseInsensitive) ?? [])
      coordinator.index = 0
    } else if !coordinator.matches.isEmpty {
      coordinator.index =
        (coordinator.index + (backward ? -1 : 1) + coordinator.matches.count)
        % coordinator.matches.count
    }
    coordinator.step = step
    let matches = coordinator.matches
    view.highlightedSelections = matches
    if !matches.isEmpty {
      let match = matches[coordinator.index]
      view.setCurrentSelection(match, animate: false)
      view.go(to: match)
    } else {
      view.clearSelection()
    }
    let status =
      query.isEmpty
      ? "" : (matches.isEmpty ? "No matches" : "\(coordinator.index + 1) of \(matches.count)")
    DispatchQueue.main.async { onFind(status) }
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator {
    var data: Data?
    var zoom: Double?
    var query: String?
    var matches: [PDFSelection] = []
    var index = 0
    var step = 0
  }
}
