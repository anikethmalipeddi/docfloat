import Foundation

struct GoogleDocTab: Identifiable, Equatable, Sendable {
  let id: String
  let title: String
  let depth: Int
  let html: String
}

enum GoogleDocTabs {
  static func fetch(documentID: String, token: String) async throws -> [GoogleDocTab] {
    let url = URL(
      string: "https://docs.googleapis.com/v1/documents/\(documentID)?includeTabsContent=true")!
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    request.timeoutInterval = 20
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw GoogleOAuth.OAuthError.google(
        "Enable Google Docs API in your Google Cloud project to load document tabs.")
    }
    return try decode(data)
  }

  static func decode(_ data: Data) throws -> [GoogleDocTab] {
    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return flatten(root?["tabs"] as? [[String: Any]] ?? [], depth: 0)
  }

  private static func flatten(_ tabs: [[String: Any]], depth: Int) -> [GoogleDocTab] {
    tabs.flatMap { tab -> [GoogleDocTab] in
      var result: [GoogleDocTab] = []
      if let properties = tab["tabProperties"] as? [String: Any],
        let id = properties["tabId"] as? String
      {
        let document = tab["documentTab"] as? [String: Any]
        let body = document?["body"] as? [String: Any]
        let content = render(body?["content"] as? [[String: Any]] ?? [])
        let html = """
          <!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">
          <style>body{font:17px/1.6 -apple-system,sans-serif;color:#202124;background:#fff;margin:0;padding:28px;overflow-wrap:anywhere}p{margin:0 0 12px;white-space:pre-wrap}table{border-collapse:collapse;width:100%}td{border:1px solid #ddd;padding:8px;vertical-align:top}h1,h2,h3,h4,h5,h6{line-height:1.3}img{max-width:100%}</style>
          \(content)
          """
        result.append(
          GoogleDocTab(
            id: id, title: properties["title"] as? String ?? "Untitled tab", depth: depth,
            html: html))
      }
      result += flatten(tab["childTabs"] as? [[String: Any]] ?? [], depth: depth + 1)
      return result
    }
  }

  private static func render(_ elements: [[String: Any]]) -> String {
    elements.map { element -> String in
      if let paragraph = element["paragraph"] as? [String: Any] {
        let text = (paragraph["elements"] as? [[String: Any]] ?? []).map { item -> String in
          guard let run = item["textRun"] as? [String: Any] else { return "" }
          var text = escape(run["content"] as? String ?? "")
          let style = run["textStyle"] as? [String: Any] ?? [:]
          if style["bold"] as? Bool == true { text = "<strong>\(text)</strong>" }
          if style["italic"] as? Bool == true { text = "<em>\(text)</em>" }
          return text
        }.joined()
        let style = paragraph["paragraphStyle"] as? [String: Any]
        let named = style?["namedStyleType"] as? String ?? ""
        let level = named.replacingOccurrences(of: "HEADING_", with: "")
        let tag =
          named.hasPrefix("HEADING_") && ["1", "2", "3", "4", "5", "6"].contains(level)
          ? "h\(level)" : "p"
        let bullet = paragraph["bullet"] == nil ? "" : "• "
        return "<\(tag)>\(bullet)\(text)</\(tag)>"
      }
      if let table = element["table"] as? [String: Any] {
        let rows = (table["tableRows"] as? [[String: Any]] ?? []).map { row in
          "<tr>"
            + (row["tableCells"] as? [[String: Any]] ?? []).map { cell in
              "<td>" + render(cell["content"] as? [[String: Any]] ?? []) + "</td>"
            }.joined() + "</tr>"
        }.joined()
        return "<table>\(rows)</table>"
      }
      if let toc = element["tableOfContents"] as? [String: Any] {
        return render(toc["content"] as? [[String: Any]] ?? [])
      }
      return ""
    }.joined()
  }

  private static func escape(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }
}
