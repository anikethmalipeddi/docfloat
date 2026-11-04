import Foundation
import Testing

@testable import DocFloat

@Test func localNotesSurviveReopeningAndPreserveUnicode() throws {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "DocFloat-test-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: folder) }
  let file = folder.appendingPathComponent("My Notes.txt")
  let first = LocalNoteStore(url: file)
  #expect(try first.read() == "")
  let text = "My talking points\nCafé ☕️\nProject results: 42%"
  try first.save(text)
  #expect(try LocalNoteStore(url: file).read() == text)
  try first.save("")
  #expect(try LocalNoteStore(url: file).read() == "")
}

@MainActor @Test func localNoteSearchUsesCorrectUnicodeRanges() {
  let text = "🌟 Project one\nproject two"
  let matches = LocalNoteEditor.matches(in: text, query: "PROJECT")
  #expect(matches.count == 2)
  #expect(
    matches.map { (text as NSString).substring(with: $0).lowercased() } == ["project", "project"])
  #expect(LocalNoteEditor.matches(in: text, query: "").isEmpty)
  #expect(LocalNoteEditor.matches(in: text, query: "absent").isEmpty)
}
