import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      controls
      Divider().opacity(0.35)
      ZStack {
        if case .pdf(let data) = model.content {
          DocumentPDFView(data: data, zoom: model.zoom)
        } else {
          DocumentWebView(content: model.content, zoom: model.zoom, reloadID: model.reloadID) {
            message in
            model.errorMessage = message
          }
        }
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
    .alert(
      "DocFloat",
      isPresented: Binding(
        get: { model.errorMessage != nil },
        set: { if !$0 { model.errorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "")
    }
    .onAppear {
      if !model.docURL.isEmpty { model.loadDocument() }
    }
  }

  private var controls: some View {
    VStack(spacing: 8) {
      if !model.compact {
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
      }
      HStack(spacing: 10) {
        if model.compact {
          Text(model.documentName.isEmpty ? "DocFloat" : model.documentName)
            .font(.caption).lineLimit(1)
        } else {
          Button("Open PDF…") { model.openPDF() }
            .help("Google Docs → File → Download → PDF")
        }
        Spacer(minLength: 0)
        Image(systemName: "circle.lefthalf.filled").foregroundStyle(.secondary)
        Slider(value: $model.opacity, in: 0.2...1).frame(width: 90)
          .accessibilityLabel("Window opacity")
        Button {
          model.zoom = max(0.5, model.zoom - 0.1)
        } label: {
          Image(systemName: "minus.magnifyingglass")
        }
        .help("Zoom out")
        Button {
          model.zoom = min(3, model.zoom + 0.1)
        } label: {
          Image(systemName: "plus.magnifyingglass")
        }
        .help("Zoom in")
        Button {
          model.compact.toggle()
        } label: {
          Image(
            systemName: model.compact
              ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
        }.help("Toggle compact mode (⇧⌘K)")
      }
    }.padding(10)
  }
}
