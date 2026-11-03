import SwiftUI
import WebKit

struct DocumentWebView: NSViewRepresentable {
    let content: AppModel.DocumentContent

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastContent != content else { return }
        context.coordinator.lastContent = content

        switch content {
        case .empty:
            webView.loadHTMLString(Self.emptyHTML, baseURL: nil)
        case .publicPreview(let url):
            webView.load(URLRequest(url: url))
        case .pdf(let data):
            webView.load(data, mimeType: "application/pdf", characterEncodingName: "", baseURL: URL(string: "https://docs.google.com")!)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastContent: AppModel.DocumentContent?
    }

    private static let emptyHTML = """
    <!doctype html><meta charset="utf-8">
    <style>html,body{height:100%;margin:0;background:transparent;color:#777;font:17px -apple-system;display:grid;place-items:center;text-align:center}.box{max-width:360px;padding:30px}</style>
    <div class="box"><strong>Paste a Google Docs link above</strong><p>Public links open directly. Sign in from Settings for private documents.</p></div>
    """
}
