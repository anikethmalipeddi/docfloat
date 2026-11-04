import SwiftUI

struct MenuBarView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button("Show & Unlock DocFloat") {
      openWindow(id: "main")
      model.showWindow()
    }
    Divider()
    Button("Auto-adjust now") { model.autoAdjustNow() }
    Button("Fully readable (100%)") { model.makeFullyReadable() }
    Toggle("Click-through", isOn: $model.clickThrough)
    ForEach([0.4, 0.6, 0.8, 1.0], id: \.self) { value in
      Button("Opacity: \(Int(value * 100))%") { model.setManualOpacity(value) }
    }
    Toggle("Compact Mode", isOn: $model.compact)
    Button("Open Notes…") { model.openPDF() }
    Button("Reload Document") { model.loadDocument() }
    Divider()
    Button("Quit DocFloat") { NSApp.terminate(nil) }
  }
}
