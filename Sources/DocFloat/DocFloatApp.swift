import SwiftUI

@main
struct DocFloatApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 520, minHeight: 360)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 760, height: 650)

        MenuBarExtra("DocFloat", systemImage: "doc.text.magnifyingglass") {
            MenuBarView()
                .environmentObject(model)
        }
    }
}
