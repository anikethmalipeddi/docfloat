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
  let onSelectTab: (String) -> Void
  let onLoaded: () -> Void
  let onSample: (ReadingContrast) -> Void
  let onError: (String) -> Void

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.uiDelegate = context.coordinator
    webView.underPageBackgroundColor = .clear
    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {
    webView.pageZoom = zoom
    context.coordinator.onError = onError
    context.coordinator.onFind = onFind
    context.coordinator.onSelectTab = onSelectTab
    context.coordinator.onLoaded = onLoaded
    context.coordinator.onSample = onSample
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
    let sameContent = context.coordinator.lastContent == content
    context.coordinator.lastContent = content
    context.coordinator.reloadID = reloadID

    switch content {
    case .empty:
      webView.loadHTMLString(Self.emptyHTML, baseURL: nil)
    case .publicPreview(let url):
      if sameContent, let current = webView.url,
        GoogleDocURL.documentID(from: current.absoluteString)
          == GoogleDocURL.documentID(from: url.absoluteString)
      {
        webView.reloadFromOrigin()
      } else {
        webView.load(URLRequest(url: url))
      }
    case .pdf:
      break
    case .tabHTML(let html):
      webView.loadHTMLString(html, baseURL: nil)
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var lastContent: AppModel.DocumentContent?
    var reloadID: UUID?
    var onError: ((String) -> Void)?
    var onFind: ((String) -> Void)?
    var onSelectTab: ((String) -> Void)?
    var onLoaded: (() -> Void)?
    var onSample: ((ReadingContrast) -> Void)?
    var query = ""
    var step = 0

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      onLoaded?()
      let snapshot = WKSnapshotConfiguration()
      snapshot.snapshotWidth = 512
      webView.takeSnapshot(with: snapshot) { [weak self] image, _ in
        if let cg = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
          self?.onSample?(AutoOpacity.document(cg))
        }
      }
      guard !query.isEmpty else { return }
      let config = WKFindConfiguration()
      config.caseSensitive = false
      config.wraps = true
      webView.find(query, configuration: config) { [weak self] result in
        self?.onFind?(result.matchFound ? "Match found" : "No matches")
      }
    }

    func webView(
      _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      guard let url = navigationAction.request.url else {
        decisionHandler(.cancel)
        return
      }
      if url.scheme == "docfloat", url.host == "tab" {
        decisionHandler(.cancel)
        onSelectTab?(String(url.path.dropFirst()))
      } else if let current = webView.url,
        let internalURL = GoogleDocURL.internalPreviewURL(url, current: current)
      {
        if internalURL != url || navigationAction.targetFrame?.isMainFrame != true {
          decisionHandler(.cancel)
          webView.load(URLRequest(url: internalURL))
        } else {
          decisionHandler(.allow)
        }
      } else if url.host == "accounts.google.com" {
        decisionHandler(.cancel)
        onError?(
          "This linked document needs sign-in. Connect Google in Settings, or download a PDF in your browser and choose Open Notes."
        )
      } else if navigationAction.navigationType == .linkActivated,
        url.host == "docs.google.com", url.path.hasSuffix("/preview"),
        let current = webView.url,
        GoogleDocURL.documentID(from: current.absoluteString)
          == GoogleDocURL.documentID(from: url.absoluteString)
      {
        decisionHandler(.allow)
      } else if navigationAction.navigationType == .linkActivated {
        decisionHandler(.cancel)
        if url.scheme == "https" || url.scheme == "http" { NSWorkspace.shared.open(url) }
      } else {
        decisionHandler(.allow)
      }
    }

    func webView(
      _ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
      for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
      guard let url = navigationAction.request.url else { return nil }
      if let current = webView.url,
        let internalURL = GoogleDocURL.internalPreviewURL(url, current: current)
      {
        webView.load(URLRequest(url: internalURL))
      } else if url.scheme == "https" || url.scheme == "http" {
        NSWorkspace.shared.open(url)
      }
      return nil
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
    <div class="box"><strong>Your notes, within reach.</strong><p>Choose Open Notes to read a PDF above your other windows.</p><p style="font-size:13px">Want synced notes? Optionally link a Google Doc. Connect your account in Settings for private documents.</p></div>
    """
}
