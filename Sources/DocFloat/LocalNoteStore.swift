import Foundation

struct LocalNoteStore {
  let url: URL
  init(url: URL? = nil) {
    self.url =
      url
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("DocFloat", isDirectory: true).appendingPathComponent("My Notes.txt")
  }
  func read() throws -> String {
    guard FileManager.default.fileExists(atPath: url.path) else { return "" }
    return try String(contentsOf: url, encoding: .utf8)
  }
  func save(_ text: String) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: url, atomically: true, encoding: .utf8)
  }
}
