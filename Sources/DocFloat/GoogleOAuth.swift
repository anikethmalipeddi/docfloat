import AppKit
import CryptoKit
import Foundation

@MainActor
final class GoogleOAuth: ObservableObject {
    struct TokenResponse: Decodable {
        let accessToken: String
        let expiresIn: Int
        let refreshToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
        }
    }

    enum OAuthError: LocalizedError {
        case missingClientID
        case badResponse
        case google(String)

        var errorDescription: String? {
            switch self {
            case .missingClientID: return "Add a Google OAuth desktop client ID in Settings first."
            case .badResponse: return "Google returned an unexpected response."
            case .google(let message): return message
            }
        }
    }

    @Published var clientID: String {
        didSet { UserDefaults.standard.set(clientID, forKey: "googleClientID") }
    }
    @Published private(set) var isAuthenticated: Bool

    private var accessToken: String?
    private var expiry: Date?
    private let refreshAccount = "googleRefreshToken"

    init() {
        clientID = UserDefaults.standard.string(forKey: "googleClientID") ?? ""
        isAuthenticated = KeychainStore.read(account: refreshAccount) != nil
    }

    func authorize() async throws {
        let cleanClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanClientID.isEmpty else { throw OAuthError.missingClientID }

        let server = try OAuthCallbackServer()
        let port = try await server.start()
        let redirectURI = "http://127.0.0.1:\(port)/callback"
        let verifier = Self.randomURLSafeString(byteCount: 48)
        let challengeData = Data(SHA256.hash(data: Data(verifier.utf8)))
        let challenge = challengeData.base64URLEncodedString()
        let state = Self.randomURLSafeString(byteCount: 24)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: cleanClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/drive.readonly"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else { throw OAuthError.badResponse }
        NSWorkspace.shared.open(authURL)
        let callback = try await server.waitForCallback()
        guard callback.state == state else {
            throw OAuthError.google("Google sign-in state verification failed. Please try again.")
        }

        let token = try await requestToken(parameters: [
            "client_id": cleanClientID,
            "code": callback.code,
            "code_verifier": verifier,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ])
        try store(token)
    }

    func validAccessToken() async throws -> String {
        if let accessToken, let expiry, expiry > Date().addingTimeInterval(60) {
            return accessToken
        }

        guard let refreshToken = KeychainStore.read(account: refreshAccount) else {
            throw OAuthError.google("Sign in to view a private Google Doc.")
        }
        let cleanClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanClientID.isEmpty else { throw OAuthError.missingClientID }

        let token = try await requestToken(parameters: [
            "client_id": cleanClientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ])
        try store(token)
        return token.accessToken
    }

    func disconnect() {
        KeychainStore.delete(account: refreshAccount)
        accessToken = nil
        expiry = nil
        isAuthenticated = false
    }

    private func requestToken(parameters: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OAuthError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let description = payload?["error_description"] as? String
            let error = payload?["error"] as? String
            throw OAuthError.google(description ?? error ?? "Google sign-in failed.")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func store(_ token: TokenResponse) throws {
        accessToken = token.accessToken
        expiry = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        if let refreshToken = token.refreshToken {
            try KeychainStore.save(refreshToken, account: refreshAccount)
        }
        isAuthenticated = KeychainStore.read(account: refreshAccount) != nil
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
