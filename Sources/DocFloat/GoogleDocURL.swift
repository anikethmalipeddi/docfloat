import Foundation

enum GoogleDocURL {
  static func documentID(from input: String) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    if isValidID(trimmed) {
      return trimmed
    }

    guard let url = URL(string: trimmed),
      let host = url.host?.lowercased(),
      url.scheme == "https", host == "docs.google.com"
    else {
      return nil
    }

    let parts = url.pathComponents
    guard parts.contains("document"), let dIndex = parts.firstIndex(of: "d"),
      parts.indices.contains(dIndex + 1)
    else {
      return nil
    }

    let id = parts[dIndex + 1]
    return isValidID(id) ? id : nil
  }

  private static func isValidID(_ value: String) -> Bool {
    value.range(of: "^[A-Za-z0-9_-]{20,}$", options: .regularExpression) != nil
  }

  static func previewURL(for documentID: String) -> URL {
    URL(string: "https://docs.google.com/document/d/\(documentID)/preview")!
  }

  static func editURL(for documentID: String) -> URL {
    URL(string: "https://docs.google.com/document/d/\(documentID)/edit")!
  }

  static func internalPreviewURL(_ target: URL, current: URL) -> URL? {
    // Google sometimes wraps document links in a google.com/url redirect.
    var target = target
    if ["www.google.com", "google.com"].contains(target.host ?? ""), target.path == "/url",
      let items = URLComponents(url: target, resolvingAgainstBaseURL: false)?.queryItems,
      let value = items.first(where: { $0.name == "q" || $0.name == "url" })?.value,
      let unwrapped = URL(string: value)
    {
      target = unwrapped
    }
    guard let id = documentID(from: current.absoluteString) else { return nil }
    let resolved = URL(string: target.relativeString, relativeTo: current)?.absoluteURL ?? target
    guard documentID(from: resolved.absoluteString) == id else { return nil }
    var result = URLComponents(url: resolved, resolvingAgainstBaseURL: false)!
    result.path = "/document/d/\(id)/preview"
    return result.url
  }
}
