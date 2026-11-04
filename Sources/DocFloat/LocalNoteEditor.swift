import AppKit
import SwiftUI

struct LocalNoteEditor: NSViewRepresentable {
  @Binding var text: String
  let zoom: Double
  let query: String
  let step: Int
  let backward: Bool
  let onFind: (String) -> Void

  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSScrollView()
    scroll.hasVerticalScroller = true
    let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    editor.isRichText = false
    editor.allowsUndo = true
    editor.isVerticallyResizable = true
    editor.isHorizontallyResizable = false
    editor.autoresizingMask = [.width]
    editor.textContainer?.widthTracksTextView = true
    editor.textContainerInset = NSSize(width: 20, height: 20)
    editor.isAutomaticQuoteSubstitutionEnabled = false
    editor.isAutomaticDashSubstitutionEnabled = false
    editor.setAccessibilityLabel("My Notes editor")
    editor.delegate = context.coordinator
    scroll.documentView = editor
    DispatchQueue.main.async { editor.window?.makeFirstResponder(editor) }
    return scroll
  }

  func updateNSView(_ scroll: NSScrollView, context: Context) {
    guard let editor = scroll.documentView as? NSTextView else { return }
    context.coordinator.parent = self
    if editor.string != text { editor.string = text }
    if editor.font?.pointSize != 17 * zoom { editor.font = .systemFont(ofSize: 17 * zoom) }
    editor.textColor = .textColor
    editor.backgroundColor = .textBackgroundColor
    let coordinator = context.coordinator
    guard coordinator.lastText != text || coordinator.query != query || coordinator.step != step
    else { return }
    let queryChanged = coordinator.query != query || coordinator.lastText != text
    coordinator.lastText = text
    coordinator.query = query
    editor.layoutManager?.removeTemporaryAttribute(
      .backgroundColor, forCharacterRange: NSRange(location: 0, length: (text as NSString).length))
    let matches = Self.matches(in: text, query: query)
    if queryChanged {
      coordinator.index = 0
    } else if !matches.isEmpty && coordinator.step != step {
      coordinator.index = (coordinator.index + (backward ? -1 : 1) + matches.count) % matches.count
    }
    coordinator.step = step
    for match in matches {
      editor.layoutManager?.addTemporaryAttribute(
        .backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.4),
        forCharacterRange: match)
    }
    if !matches.isEmpty {
      let match = matches[min(coordinator.index, matches.count - 1)]
      editor.scrollRangeToVisible(match)
      editor.showFindIndicator(for: match)
    }
    let status =
      query.isEmpty
      ? "" : (matches.isEmpty ? "No matches" : "\(coordinator.index + 1) of \(matches.count)")
    DispatchQueue.main.async { onFind(status) }
  }

  static func matches(in text: String, query: String) -> [NSRange] {
    guard !query.isEmpty else { return [] }
    let source = text as NSString
    var result: [NSRange] = []
    var start = 0
    while start < source.length {
      let range = source.range(
        of: query, options: .caseInsensitive,
        range: NSRange(location: start, length: source.length - start))
      guard range.location != NSNotFound else { break }
      result.append(range)
      start = NSMaxRange(range)
    }
    return result
  }

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: LocalNoteEditor
    var lastText = ""
    var query = ""
    var step = 0
    var index = 0
    init(parent: LocalNoteEditor) { self.parent = parent }
    func textDidChange(_ notification: Notification) {
      if let editor = notification.object as? NSTextView { parent.text = editor.string }
    }
  }
}
