import AppKit
import SwiftUI
import WebKit

struct DocumentWebView: NSViewRepresentable {
  let content: AppModel.DocumentContent
  let zoom: Double
  let reloadID: UUID
  let query: String
  let step: Int
  let backward: Bool
  let onFind: (String) -> Void
  let onError: (String) -> Void

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.underPageBackgroundColor = .clear
    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {
    webView.pageZoom = zoom
    context.coordinator.onError = onError
    if context.coordinator.query != query || context.coordinator.step != step {
      context.coordinator.query = query
      context.coordinator.step = step
      let configuration = WKFindConfiguration()
      configuration.backwards = backward
      configuration.caseSensitive = false
      configuration.wraps = true
      webView.find(query, configuration: configuration) { result in
        onFind(query.isEmpty ? "" : (result.matchFound ? "Match found" : "No matches"))
      }
    }
    guard context.coordinator.lastContent != content || context.coordinator.reloadID != reloadID
    else { return }
    context.coordinator.lastContent = content
    context.coordinator.reloadID = reloadID

    switch content {
    case .empty:
      webView.loadHTMLString(Self.emptyHTML, baseURL: nil)
    case .publicPreview(let url):
      webView.load(URLRequest(url: url))
    case .pdf:
      break
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator: NSObject, WKNavigationDelegate {
    var lastContent: AppModel.DocumentContent?
    var reloadID: UUID?
    var onError: ((String) -> Void)?
    var query = ""
    var step = 0

    func webView(
      _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      guard let url = navigationAction.request.url else {
        decisionHandler(.cancel)
        return
      }
      if url.host == "accounts.google.com" {
        decisionHandler(.cancel)
        onError?(
          "This document needs sign-in. Use Settings to connect Google, or download it as a PDF in your browser and choose Open PDF."
        )
      } else if navigationAction.navigationType == .linkActivated {
        decisionHandler(.cancel)
        if url.scheme == "https" || url.scheme == "http" { NSWorkspace.shared.open(url) }
      } else {
        decisionHandler(.allow)
      }
    }

    func webView(
      _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      if (error as NSError).code != NSURLErrorCancelled { onError?(error.localizedDescription) }
    }
  }

  private static let emptyHTML = """
    <!doctype html><meta charset="utf-8">
    <style>html,body{height:100%;margin:0;background:transparent;color:#777;font:17px -apple-system;display:grid;place-items:center;text-align:center}.box{max-width:360px;padding:30px}</style>
    <div class="box"><strong>Your notes, within reach.</strong><p>Paste a shared Google Docs link, or open a PDF.</p><p style="font-size:13px">For a private Doc: File → Download → PDF in Google Docs, then Open PDF here. Google sign-in is also available in Settings.</p></div>
    """
}
