import Foundation
import Testing

@testable import DocFloat

@Test func sameDocumentLinksStayInsidePreviewWithTabAndHeading() {
  let id = "1AbCdEfGhIjKlMnOpQrStUvWxYz"
  let current = GoogleDocURL.previewURL(for: id)
  let target = URL(
    string: "https://docs.google.com/document/d/\(id)/edit?tab=t.child#heading=h.example")!
  let routed = GoogleDocURL.internalPreviewURL(target, current: current)
  #expect(routed?.path == "/document/d/\(id)/preview")
  #expect(routed?.query == "tab=t.child")
  #expect(routed?.fragment == "heading=h.example")
  #expect(
    GoogleDocURL.internalPreviewURL(URL(string: "https://example.com")!, current: current) == nil)
  let wrapped = URL(
    string: "https://www.google.com/url?q=" + target.absoluteString.addingPercentEncoding(
      withAllowedCharacters: .alphanumerics)!)!
  #expect(GoogleDocURL.internalPreviewURL(wrapped, current: current) == routed)
  #expect(
    GoogleDocURL.internalPreviewURL(URL(string: "#heading=h.local")!, current: current)?.fragment
      == "heading=h.local")
}

@Test func extractsDocumentID() {
  let id = "1AbCdEfGhIjKlMnOpQrStUvWxYz123456789"
  #expect(
    GoogleDocURL.documentID(from: "https://docs.google.com/document/d/\(id)/edit?tab=t.0") == id
  )
}

@Test func acceptsBareID() {
  #expect(
    GoogleDocURL.documentID(from: "1AbCdEfGhIjKlMnOpQrStUvWxYz") == "1AbCdEfGhIjKlMnOpQrStUvWxYz"
  )
}

@Test func rejectsNonGoogleHost() {
  #expect(
    GoogleDocURL.documentID(from: "https://example.com/document/d/1AbCdEfGhIjKlMnOpQrStUvWxYz/edit")
      == nil
  )
}

@Test func rejectsMalformedAndNonDocumentLinks() {
  for value in [
    "this is not a document ID",
    "https://docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz/edit",
    "https://docs.google.com/document/d/../../edit",
    "http://docs.google.com/document/d/1AbCdEfGhIjKlMnOpQrStUvWxYz/edit",
  ] {
    #expect(GoogleDocURL.documentID(from: value) == nil)
  }
}
