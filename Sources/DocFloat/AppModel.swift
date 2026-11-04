import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
  enum DocumentContent: Equatable {
    case empty
    case publicPreview(URL)
    case pdf(Data)
    case tabHTML(String)
  }

  @Published var docURL: String {
    didSet { UserDefaults.standard.set(docURL, forKey: "lastDocURL") }
  }
  @Published var opacity: Double {
    didSet {
      UserDefaults.standard.set(opacity, forKey: "windowOpacity")
      configureWindow()
    }
  }
  @Published var clickThrough = false {
    didSet { configureWindow() }
  }
  @Published var adaptiveContrast =
    UserDefaults.standard.object(forKey: "adaptiveContrast") as? Bool ?? true
  {
    didSet {
      UserDefaults.standard.set(adaptiveContrast, forKey: "adaptiveContrast")
      configureWindow()
    }
  }
  @Published var contrastStatus = "Click Auto-adjust to calculate opacity"
  @Published var contrastDetails = "No background sample yet"
  @Published var contrastPermissionNeeded = !CGPreflightScreenCaptureAccess()
  private var documentContrast = ReadingContrast.standard
  private var contrastTask: Task<Void, Never>?

  func setManualOpacity(_ value: Double) {
    contrastTask?.cancel()
    adaptiveContrast = false
    opacity = min(1, max(0, value))
    contrastStatus = "Manual"
  }

  func sampleDocument(_ contrast: ReadingContrast) { documentContrast = contrast }

  func autoAdjustNow() {
    adaptiveContrast = true
    if !CGPreflightScreenCaptureAccess() {
      contrastPermissionNeeded = true
      contrastStatus = "Permission needed · opacity unchanged"
      showingSettings = true
      return
    }
    contrastPermissionNeeded = false
    contrastStatus = "Measuring background…"
    adjustContrastOnce()
  }

  func makeFullyReadable() {
    setManualOpacity(1)
    contrastStatus = "Fully readable · 100%"
  }

  func requestContrastPermission() {
    adaptiveContrast = true
    if !CGRequestScreenCaptureAccess() {
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
      {
        NSWorkspace.shared.open(url)
      }
    }
  }

  private func adjustContrastOnce() {
    contrastTask?.cancel()
    guard adaptiveContrast, window != nil else { return }
    contrastTask = Task { [weak self] in
      if !Task.isCancelled {
        if let self, let window = self.window {
          if CGPreflightScreenCaptureAccess() {
            self.contrastPermissionNeeded = false
            do {
              let background = try await AutoOpacity.background(behind: window)
              try Task.checkCancellation()
              let target = AutoOpacity.recommendation(
                document: self.documentContrast, background: background)
              if abs(self.opacity - target) >= 0.02 { self.opacity = target }
              let brightness =
                background.isEmpty ? 0 : background.reduce(0, +) / Double(background.count)
              self.contrastStatus =
                "Auto · \(Int(self.opacity * 100))% · BG \(Int(brightness * 100))%"
              self.contrastDetails =
                "Sampled " + Date.now.formatted(date: .omitted, time: .standard)
                + " · document tones \(Int(self.documentContrast.dark * 100))–\(Int(self.documentContrast.light * 100))%"
            } catch {
              if Task.isCancelled { return }
              self.contrastStatus = "Auto unavailable: \(error.localizedDescription)"
            }
          } else {
            self.contrastPermissionNeeded = true
            self.contrastStatus =
              "Permission needed · background not sampled"
          }
        }
      }
    }
  }
  @Published var requestCaptureExclusion =
    UserDefaults.standard.object(forKey: "requestCaptureExclusion") as? Bool ?? true
  {
    didSet {
      UserDefaults.standard.set(requestCaptureExclusion, forKey: "requestCaptureExclusion")
      configureWindow()
    }
  }
  @Published var content: DocumentContent = .empty
  @Published var isEditingNote = UserDefaults.standard.bool(forKey: "localEditorActive") {
    didSet { UserDefaults.standard.set(isEditingNote, forKey: "localEditorActive") }
  }
  @Published var localNote = "" {
    didSet {
      do {
        try noteStore.save(localNote)
        noteSaveStatus = "Saved on this Mac"
      } catch { noteSaveStatus = "Not saved: \(error.localizedDescription)" }
    }
  }
  @Published var noteSaveStatus = "Saved on this Mac"
  private let noteStore = LocalNoteStore()

  func editLocalNote() {
    loadTask?.cancel()
    isLoading = false
    isEditingNote = true
    clickThrough = false
    documentName = "My Notes"
    syncStatus = ""
    findStatus = ""
    sampleDocument(.standard)
  }
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var showingSettings = false
  @Published var compact = false
  @Published var showingFind = false
  @Published var findQuery = ""
  @Published var findStatus = ""
  @Published var findStep = 0
  @Published var findBackward = false

  func openFind() {
    clickThrough = false
    showingFind = true
  }

  func nextMatch(backward: Bool = false) {
    findBackward = backward
    findStep += 1
  }
  @Published var zoom: Double = 1
  @Published var documentName = ""
  @Published var reloadID = UUID()
  @Published var syncStatus = ""
  @Published var tabs: [GoogleDocTab] = []
  @Published var selectedTabID = "" {
    didSet {
      if let tab = tabs.first(where: { $0.id == selectedTabID }) {
        content = .tabHTML(tab.html)
        findStatus = ""
      }
    }
  }

  func applyTabs(_ updated: [GoogleDocTab]) {
    tabs = updated
    guard !updated.isEmpty else {
      selectedTabID = ""
      content = .empty
      return
    }
    if !updated.contains(where: { $0.id == selectedTabID }) {
      selectedTabID = updated.first?.id ?? ""
    } else if let selected = updated.first(where: { $0.id == selectedTabID }) {
      content = .tabHTML(selected.html)
    }
  }
  private var loadedDocumentID: String?
  private var loadTask: Task<Void, Never>?
  @Published var window: NSWindow? {
    didSet {
      configureWindow()
    }
  }

  let oauth = GoogleOAuth()

  init() {
    do { localNote = try noteStore.read() } catch {
      noteSaveStatus = "Could not read saved notes: \(error.localizedDescription)"
    }
    docURL = UserDefaults.standard.string(forKey: "lastDocURL") ?? ""
    let savedOpacity = UserDefaults.standard.double(forKey: "windowOpacity")
    opacity =
      UserDefaults.standard.object(forKey: "windowOpacity") == nil
      ? 0.8 : min(1, max(0, savedOpacity))
  }

  func loadDocument() {
    guard let id = GoogleDocURL.documentID(from: docURL) else {
      errorMessage = "Paste a valid Google Docs URL."
      return
    }

    errorMessage = nil
    isEditingNote = false
    loadTask?.cancel()
    if loadedDocumentID != id {
      tabs = []
      let parts = URLComponents(string: docURL)
      selectedTabID = parts?.queryItems?.first(where: { $0.name == "tab" })?.value ?? ""
    }
    if let linkedTab = Self.linkedTabID(in: docURL) { selectedTabID = linkedTab }
    loadedDocumentID = id
    syncStatus = ""
    documentName = "Google Doc"
    reloadID = UUID()
    if oauth.isAuthenticated {
      loadTask = Task { await loadPrivateDocument(id: id) }
    } else {
      isLoading = false
      let preview = GoogleDocURL.previewURL(for: id)
      let linked = URL(string: docURL).flatMap {
        GoogleDocURL.internalPreviewURL($0, current: preview)
      }
      content = .publicPreview(linked ?? preview)
    }
  }

  func signIn() {
    Task {
      do {
        isLoading = true
        try await oauth.authorize()
        isLoading = false
        loadDocument()
      } catch {
        isLoading = false
        errorMessage = error.localizedDescription
      }
    }
  }

  func disconnect() {
    oauth.disconnect()
    loadTask?.cancel()
    loadedDocumentID = nil
    tabs = []
    syncStatus = ""
    content = .empty
    isLoading = false
  }

  func openPDF() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.pdf]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      let data = try Data(contentsOf: url)
      guard PDFDocument(data: data) != nil else {
        errorMessage = "This file could not be opened as a PDF."
        return
      }
      loadTask?.cancel()
      isEditingNote = false
      loadedDocumentID = nil
      tabs = []
      syncStatus = ""
      isLoading = false
      content = .pdf(data)
      documentName = url.deletingPathExtension().lastPathComponent
      reloadID = UUID()
    } catch { errorMessage = error.localizedDescription }
  }

  func openInBrowser() {
    guard let id = loadedDocumentID ?? GoogleDocURL.documentID(from: docURL) else { return }
    var url = URLComponents(url: GoogleDocURL.editURL(for: id), resolvingAgainstBaseURL: false)!
    if !selectedTabID.isEmpty { url.queryItems = [URLQueryItem(name: "tab", value: selectedTabID)] }
    NSWorkspace.shared.open(url.url!)
  }

  static func linkedTabID(in input: String) -> String? {
    guard let parts = URLComponents(string: input) else { return nil }
    let query = parts.queryItems ?? []
    let fragment =
      URLComponents(string: "https://local/?" + (parts.fragment ?? ""))?.queryItems ?? []
    return (query + fragment).first(where: { $0.name == "tab" && $0.value?.isEmpty == false })?
      .value
  }

  func selectLinkedTab(_ id: String) {
    guard tabs.contains(where: { $0.id == id }) else { return }
    selectedTabID = id
  }

  func showWindow() {
    clickThrough = false
    if opacity < 0.05 { setManualOpacity(0.8) }
    NSApplication.shared.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }

  private func loadPrivateDocument(id: String) async {
    do {
      isLoading = true
      let token = try await oauth.validAccessToken()
      if let docTabs = try? await GoogleDocTabs.fetch(documentID: id, token: token),
        !docTabs.isEmpty
      {
        try Task.checkCancellation()
        applyTabs(docTabs)
        syncStatus = "Updated just now"
        isLoading = false
        return
      }
      let data = try await DriveClient.exportPDF(documentID: id, accessToken: token)
      try Task.checkCancellation()
      guard PDFDocument(data: data) != nil else {
        throw GoogleOAuth.OAuthError.google("Google did not return a readable PDF.")
      }
      content = .pdf(data)
      tabs = []
      syncStatus = "PDF view · tab navigation unavailable"
      isLoading = false
    } catch {
      guard !Task.isCancelled else { return }
      isLoading = false
      errorMessage = error.localizedDescription
    }
  }

  private func configureWindow() {
    guard let window else { return }
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.isOpaque = false
    window.backgroundColor = .clear
    window.alphaValue = opacity
    window.hasShadow = true
    window.ignoresMouseEvents = clickThrough
    // Legacy capture clients may honor this; ScreenCaptureKit can ignore it.
    window.sharingType = requestCaptureExclusion ? .none : .readOnly
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
  }
}
