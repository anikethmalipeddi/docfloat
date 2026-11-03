import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider().opacity(0.35)
            ZStack {
                DocumentWebView(content: model.content)
                if model.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .background(.ultraThinMaterial)
        .background(WindowAccessor(window: $model.window))
        .sheet(isPresented: $model.showingSettings) {
            SettingsView(oauth: model.oauth)
                .environmentObject(model)
        }
        .alert("DocFloat", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onAppear {
            if !model.docURL.isEmpty { model.loadDocument() }
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
            TextField("Paste a Google Docs URL", text: $model.docURL)
                .textFieldStyle(.plain)
                .onSubmit { model.loadDocument() }
            Button("Load") { model.loadDocument() }
                .buttonStyle(.borderedProminent)
            Button {
                model.openInBrowser()
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .help("Open the original in your browser")
            Button {
                model.showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
        }
        .padding(12)
    }
}
