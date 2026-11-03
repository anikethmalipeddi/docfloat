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
}
