import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var model: AppModel
  @FocusState private var findFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      controls
      if !model.tabs.isEmpty {
        Picker("Document tab", selection: $model.selectedTabID) {
          ForEach(model.tabs) { tab in
            Text(String(repeating: "  ", count: tab.depth) + tab.title).tag(tab.id)
          }
        }
        .pickerStyle(.menu)
        .padding(.horizontal, 10).padding(.bottom, 8)
      }
      if model.showingFind {
        HStack {
          TextField("Find in document", text: $model.findQuery)
            .textFieldStyle(.roundedBorder)
            .focused($findFocused)
            .task { findFocused = true }
            .onSubmit { model.nextMatch() }
          Text(model.findStatus).font(.caption).foregroundStyle(.secondary)
          Button {
            model.nextMatch(backward: true)
          } label: {
            Image(systemName: "chevron.up")
          }
          .help("Previous match (⇧⌘G)")
          Button {
            model.nextMatch()
          } label: {
            Image(systemName: "chevron.down")
          }
          .help("Next match (Return or ⌘G)")
          Button("Done") {
            model.showingFind = false
            model.findQuery = ""
          }
          .keyboardShortcut(.cancelAction)
        }.padding(.horizontal, 10).padding(.bottom, 8)
      }
      Divider().opacity(0.35)
      ZStack {
        if case .pdf(let data) = model.content {
          DocumentPDFView(
            data: data, zoom: model.zoom, query: model.findQuery,
            step: model.findStep, backward: model.findBackward,
            onSample: { model.sampleDocument($0) }
          ) { status in
            if model.findStatus != status { model.findStatus = status }
          }
        } else {
          DocumentWebView(
            content: model.content, zoom: model.zoom, reloadID: model.reloadID,
            query: model.findQuery, step: model.findStep, backward: model.findBackward,
            onFind: { model.findStatus = $0 }, onSelectTab: { model.selectLinkedTab($0) },
            onLoaded: {
              if case .publicPreview = model.content {
                model.syncStatus = "Updated " + Date.now.formatted(date: .omitted, time: .shortened)
              }
            }, onSample: { model.sampleDocument($0) }
          ) {
            message in
            model.errorMessage = message
          }
          .id(model.selectedTabID)
        }
        if model.isLoading {
          ProgressView()
            .controlSize(.large)
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
      }
    }
    .background {
      if model.adaptiveContrast {
        AdaptiveBackdrop()
      } else {
        Rectangle().fill(.ultraThinMaterial)
      }
    }
    .overlay {
      if model.adaptiveContrast {
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
          .allowsHitTesting(false)
      }
    }
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
    .onChange(of: model.showingFind) { _, visible in findFocused = visible }
  }

  private var controls: some View {
    VStack(spacing: 8) {
      if !model.compact {
        HStack(spacing: 10) {
          Image(systemName: "doc.text")
            .foregroundStyle(.secondary)
          TextField("Google Docs link (optional)", text: $model.docURL)
            .textFieldStyle(.plain)
            .onSubmit { model.loadDocument() }
          Button("Load") { model.loadDocument() }
            .buttonStyle(.borderedProminent)
          Button("Open Notes…") { model.openPDF() }
            .help("Open your notes as a PDF")
          Button {
            model.openInBrowser()
          } label: {
            Image(systemName: "arrow.up.forward.app")
          }
          .help("Edit in your browser; changes refresh here every 15 seconds")
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
            .frame(maxWidth: 90)
        }
        Spacer(minLength: 0)
        if !model.compact {
          Text(model.adaptiveContrast ? model.contrastStatus : model.syncStatus)
            .font(.caption2)
            .foregroundStyle(
              model.adaptiveContrast && model.contrastPermissionNeeded
                ? Color.orange : Color.secondary
            )
            .lineLimit(1).help(model.adaptiveContrast ? model.contrastStatus : model.syncStatus)
        }
        Button {
          model.openFind()
          findFocused = true
        } label: {
          Image(systemName: "magnifyingglass")
        }
        .help("Find (⌃F or ⌘F)")
        Image(systemName: "circle.lefthalf.filled").foregroundStyle(.secondary)
        Button("Auto-adjust") { model.autoAdjustNow() }
          .help(
            "Calculate opacity from the actual background. If permission is missing, opens setup without changing opacity."
          )
          .contextMenu {
            Button("Fully readable (100%)") { model.makeFullyReadable() }
            Button("Enable background sampling…") { model.requestContrastPermission() }
          }
        Slider(
          value: Binding(get: { model.opacity }, set: { model.setManualOpacity($0) }), in: 0...1
        ).frame(width: 70)
          .accessibilityLabel("Window opacity")
          .help(
            "\(model.contrastStatus). \(model.contrastDetails). Manual opacity: 0–100%. Restore a hidden window from the menu-bar icon."
          )
        Text("\(Int(model.opacity * 100))%")
          .font(.caption).monospacedDigit().frame(width: 34)
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
