import Foundation
import Network

final class OAuthCallbackServer: @unchecked Sendable {
  struct Callback: Sendable {
    let code: String
    let state: String
  }

  enum ServerError: LocalizedError {
    case failed(String)
    case invalidCallback

    var errorDescription: String? {
      switch self {
      case .failed(let message): return "Could not start the local sign-in callback: \(message)"
      case .invalidCallback: return "Google returned an invalid sign-in callback."
      }
    }
  }

  private let listener: NWListener
  private let queue = DispatchQueue(label: "DocFloat.OAuthCallback")
  private var callbackContinuation: CheckedContinuation<Callback, Error>?
  private var pendingResult: Result<Callback, Error>?
  private var finished = false

  init() throws {
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
    listener = try NWListener(using: parameters)
  }

  func start() async throws -> UInt16 {
    try await withCheckedThrowingContinuation { continuation in
      listener.stateUpdateHandler = { [weak self] state in
        guard let self else { return }
        switch state {
        case .ready:
          self.listener.stateUpdateHandler = nil
          guard let port = self.listener.port?.rawValue else {
            continuation.resume(throwing: ServerError.failed("No port was assigned."))
            return
          }
          continuation.resume(returning: port)
        case .failed(let error):
          self.listener.stateUpdateHandler = nil
          continuation.resume(throwing: ServerError.failed(error.localizedDescription))
        default:
          break
        }
      }

      listener.newConnectionHandler = { [weak self] connection in
        self?.handle(connection)
      }
      listener.start(queue: queue)
      queue.asyncAfter(deadline: .now() + 180) { [weak self] in
        self?.finish(with: .failure(ServerError.failed("Sign-in timed out. Please try again.")))
      }
    }
  }

  func waitForCallback() async throws -> Callback {
    try await withCheckedThrowingContinuation { continuation in
      queue.async { [weak self] in
        guard let self else { return }
        if let pendingResult {
          self.pendingResult = nil
          continuation.resume(with: pendingResult)
        } else {
          self.callbackContinuation = continuation
        }
      }
    }
  }

  func stop() {
    listener.cancel()
  }

  private func handle(_ connection: NWConnection) {
    connection.start(queue: queue)
    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) {
      [weak self] data, _, _, error in
      guard let self else { return }
      let result: Result<Callback, Error>

      if let error {
        result = .failure(ServerError.failed(error.localizedDescription))
      } else if let data,
        let request = String(data: data, encoding: .utf8),
        let firstLine = request.components(separatedBy: "\r\n").first,
        let target = firstLine.split(separator: " ").dropFirst().first,
        let components = URLComponents(string: "http://127.0.0.1\(target)"),
        let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
        let state = components.queryItems?.first(where: { $0.name == "state" })?.value
      {
        result = .success(Callback(code: code, state: state))
      } else {
        result = .failure(ServerError.invalidCallback)
      }

      let html = """
        <!doctype html><meta charset="utf-8"><title>DocFloat</title>
        <style>body{font:16px -apple-system;padding:48px;max-width:600px;margin:auto}h1{font-size:26px}</style>
        <h1>Return to DocFloat</h1><p>You can close this tab. DocFloat will show your sign-in result.</p>
        """
      let response =
        "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
      connection.send(
        content: Data(response.utf8),
        completion: .contentProcessed { _ in
          connection.cancel()
        })
      self.finish(with: result)
    }
  }

  private func finish(with result: Result<Callback, Error>) {
    guard !finished else { return }
    finished = true
    if let callbackContinuation {
      self.callbackContinuation = nil
      callbackContinuation.resume(with: result)
    } else {
      pendingResult = result
    }
    stop()
  }
}
