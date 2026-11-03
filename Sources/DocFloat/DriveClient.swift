import Foundation

enum DriveClient {
  enum DriveError: LocalizedError {
    case requestFailed(Int, String)

    var errorDescription: String? {
      switch self {
      case .requestFailed(let status, let message):
        return "Google Drive export failed (\(status)): \(message)"
      }
    }
  }

  static func exportPDF(documentID: String, accessToken: String) async throws -> Data {
    var components = URLComponents(
      string: "https://www.googleapis.com/drive/v3/files/\(documentID)/export")!
    components.queryItems = [URLQueryItem(name: "mimeType", value: "application/pdf")]
    var request = URLRequest(url: components.url!)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse,
      (200..<300).contains(http.statusCode)
    else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      let message = String(data: data, encoding: .utf8) ?? "Unknown error"
      throw DriveError.requestFailed(status, message)
    }
    return data
  }
}
