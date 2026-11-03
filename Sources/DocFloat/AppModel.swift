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
  @Published var requestCaptureExclusion =
    UserDefaults.standard.object(forKey: "requestCaptureExclusion") as? Bool ?? true
  {
    didSet {
      UserDefaults.standard.set(requestCaptureExclusion, forKey: "requestCaptureExclusion")
      configureWindow()
    }
  }
  @Published var content: DocumentContent = .empty
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
  @Published var autoRefresh = true {
    didSet { startAutoRefresh() }
  }
  @Published var syncStatus = ""
  private var loadedDocumentID: String?
  private var refreshTask: Task<Void, Never>?
  private var loadTask: Task<Void, Never>?
  @Published var window: NSWindow? {
    didSet { configureWindow() }
  }

  let oauth = GoogleOAuth()

  init() {
    docURL = UserDefaults.standard.string(forKey: "lastDocURL") ?? ""
    let savedOpacity = UserDefaults.standard.double(forKey: "windowOpacity")
    opacity = savedOpacity == 0 ? 0.82 : savedOpacity
  }

  func loadDocument() {
    guard let id = GoogleDocURL.documentID(from: docURL) else {
      errorMessage = "Paste a valid Google Docs URL."
      return
    }

    errorMessage = nil
    loadTask?.cancel()
    refreshTask?.cancel()
    loadedDocumentID = id
    syncStatus = ""
    documentName = "Google Doc"
    reloadID = UUID()
    if oauth.isAuthenticated {
      loadTask = Task { await loadPrivateDocument(id: id) }
    } else {
      isLoading = false
      content = .publicPreview(GoogleDocURL.previewURL(for: id))
    }
    startAutoRefresh()
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
    refreshTask?.cancel()
    loadedDocumentID = nil
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
      refreshTask?.cancel()
      loadedDocumentID = nil
      syncStatus = ""
      isLoading = false
      content = .pdf(data)
      documentName = url.deletingPathExtension().lastPathComponent
      reloadID = UUID()
    } catch { errorMessage = error.localizedDescription }
  }

  func openInBrowser() {
    guard let id = loadedDocumentID ?? GoogleDocURL.documentID(from: docURL) else { return }
    NSWorkspace.shared.open(GoogleDocURL.editURL(for: id))
  }

  func showWindow() {
    clickThrough = false
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }

  private func loadPrivateDocument(id: String) async {
    do {
      isLoading = true
      let token = try await oauth.validAccessToken()
      let data = try await DriveClient.exportPDF(documentID: id, accessToken: token)
      try Task.checkCancellation()
      guard PDFDocument(data: data) != nil else {
        throw GoogleOAuth.OAuthError.google("Google did not return a readable PDF.")
      }
      content = .pdf(data)
      syncStatus = "Updated just now"
      isLoading = false
    } catch {
      guard !Task.isCancelled else { return }
      isLoading = false
      errorMessage = error.localizedDescription
    }
  }

  private func startAutoRefresh() {
    refreshTask?.cancel()
    guard autoRefresh, let id = loadedDocumentID else { return }
    refreshTask = Task { [weak self] in
      // Allow the first load to finish, then fetch a fresh snapshot every 15 seconds.
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(15)) } catch { return }
        guard let self, !self.isLoading else { continue }
        do {
          let data: Data
          if self.oauth.isAuthenticated {
            let token = try await self.oauth.validAccessToken()
            data = try await DriveClient.exportPDF(documentID: id, accessToken: token)
          } else {
            let url = URL(string: "https://docs.google.com/document/d/\(id)/export?format=pdf")!
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.timeoutInterval = 20
            let (body, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
              throw GoogleOAuth.OAuthError.google("This Doc requires Google sign-in.")
            }
            data = body
          }
          try Task.checkCancellation()
          guard PDFDocument(data: data) != nil else {
            throw GoogleOAuth.OAuthError.google("A PDF export is unavailable for this Doc.")
          }
          if self.content != .pdf(data) { self.content = .pdf(data) }
          self.syncStatus = "Updated " + Date.now.formatted(date: .omitted, time: .shortened)
        } catch {
          guard !Task.isCancelled else { return }
          self.syncStatus = "Refresh unavailable · retrying"
        }
      }
    }
  }

  private func configureWindow() {
    guard let window else { return }
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.isOpaque = false
    window.backgroundColor = .clear
    window.alphaValue = opacity
    window.ignoresMouseEvents = clickThrough
    // Legacy capture clients may honor this; ScreenCaptureKit can ignore it.
    window.sharingType = requestCaptureExclusion ? .none : .readOnly
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
  }
}
