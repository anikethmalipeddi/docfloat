import AppKit
import Foundation

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
    @Published var content: DocumentContent = .empty
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingSettings = false
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
        if oauth.isAuthenticated {
            Task { await loadPrivateDocument(id: id) }
        } else {
            content = .publicPreview(GoogleDocURL.previewURL(for: id))
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
        loadDocument()
    }

    func openInBrowser() {
        guard let id = GoogleDocURL.documentID(from: docURL) else { return }
        NSWorkspace.shared.open(GoogleDocURL.editURL(for: id))
    }

    func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func toggleClickThrough() {
        clickThrough.toggle()
        if !clickThrough { showWindow() }
    }

    private func loadPrivateDocument(id: String) async {
        do {
            isLoading = true
            let token = try await oauth.validAccessToken()
            let data = try await DriveClient.exportPDF(documentID: id, accessToken: token)
            content = .pdf(data)
            isLoading = false
        } catch {
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
        window.ignoresMouseEvents = clickThrough
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
    }
}
