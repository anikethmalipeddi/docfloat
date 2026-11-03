import SwiftUI

@main
struct DocFloatApp: App {
  @StateObject private var model = AppModel()

  var body: some Scene {
    Window("DocFloat", id: "main") {
      ContentView()
        .environmentObject(model)
        .frame(minWidth: 520, minHeight: 360)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 760, height: 650)
    .commands {
      CommandGroup(after: .newItem) {
        Button("Open PDF…") { model.openPDF() }
          .keyboardShortcut("o")
        Button("Reload Google Doc") { model.loadDocument() }
          .keyboardShortcut("r")
      }
      CommandMenu("Reading") {
        Toggle("Compact Mode", isOn: $model.compact)
          .keyboardShortcut("k", modifiers: [.command, .shift])
        Button("Zoom In") { model.zoom = min(3, model.zoom + 0.1) }
          .keyboardShortcut("+")
        Button("Zoom Out") { model.zoom = max(0.5, model.zoom - 0.1) }
          .keyboardShortcut("-")
        Button("Actual Size") { model.zoom = 1 }
          .keyboardShortcut("0")
      }
    }

    MenuBarExtra("DocFloat", systemImage: "doc.text.magnifyingglass") {
      MenuBarView()
        .environmentObject(model)
    }
  }
}
