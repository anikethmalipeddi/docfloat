import Foundation

enum GoogleDocURL {
    static func documentID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if !trimmed.contains("/") && trimmed.count >= 20 {
            return trimmed
        }

        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased(),
              host == "docs.google.com" || host.hasSuffix(".docs.google.com") else {
            return nil
        }

        let parts = url.pathComponents
        guard let dIndex = parts.firstIndex(of: "d"), parts.indices.contains(dIndex + 1) else {
            return nil
        }

        let id = parts[dIndex + 1]
        return id.count >= 20 ? id : nil
    }

    static func previewURL(for documentID: String) -> URL {
        URL(string: "https://docs.google.com/document/d/\(documentID)/preview")!
    }

    static func editURL(for documentID: String) -> URL {
        URL(string: "https://docs.google.com/document/d/\(documentID)/edit")!
    }
}
