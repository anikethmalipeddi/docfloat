import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button("Show DocFloat") { model.showWindow() }
        Divider()
        Toggle("Click-through", isOn: $model.clickThrough)
        HStack {
            Text("Opacity")
            Slider(value: $model.opacity, in: 0.2...1.0)
                .frame(width: 140)
        }
        Button("Reload Document") { model.loadDocument() }
        Divider()
        Button("Quit DocFloat") { NSApp.terminate(nil) }
    }
}
