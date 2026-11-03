import Testing
@testable import DocFloat

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
        GoogleDocURL.documentID(from: "https://example.com/document/d/1AbCdEfGhIjKlMnOpQrStUvWxYz/edit") == nil
    )
}
