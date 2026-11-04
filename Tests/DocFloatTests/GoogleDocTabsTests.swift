import Foundation
import Testing

@testable import DocFloat

@Test func deepTabsFollowGoogleOrderAndKeepDuplicateNamesDistinct() throws {
  let json = #"""
    {"tabs":[
      {"tabProperties":{"tabId":"second","title":"Notes","index":1}},
      {"tabProperties":{"tabId":"first","title":"Notes","index":0},"childTabs":[
        {"tabProperties":{"tabId":"child","title":"Examples"},"childTabs":[
          {"tabProperties":{"tabId":"grandchild","title":"Details"},"documentTab":{"body":{"content":[{"table":{"tableRows":[{"tableCells":[{"content":[{"paragraph":{"elements":[{"textRun":{"content":"Deep note"}}]}}]}]}]}}]}}}
        ]}
      ]}
    ]}
    """#
  let tabs = try GoogleDocTabs.decode(Data(json.utf8))
  #expect(tabs.map(\.id) == ["first", "child", "grandchild", "second"])
  #expect(tabs.map(\.depth) == [0, 1, 2, 0])
  #expect(tabs[2].html.contains("<td><p>Deep note"))
}

@MainActor @Test func refreshKeepsSelectedSubtabAndHandlesRenameDeletionAndEmptyDocument() {
  let model = AppModel()
  let parent = GoogleDocTab(id: "p", title: "Parent", depth: 0, html: "parent")
  let child = GoogleDocTab(id: "c", title: "Child", depth: 1, html: "child")
  model.applyTabs([parent, child])
  model.selectLinkedTab("c")
  #expect(model.content == .tabHTML("child"))
  let renamed = GoogleDocTab(id: "c", title: "Renamed", depth: 1, html: "updated")
  model.applyTabs([parent, renamed])
  #expect(model.selectedTabID == "c")
  #expect(model.content == .tabHTML("updated"))
  model.selectLinkedTab("missing")
  #expect(model.selectedTabID == "c")
  model.applyTabs([parent])
  #expect(model.selectedTabID == "p")
  #expect(model.content == .tabHTML("parent"))
  model.applyTabs([])
  #expect(model.selectedTabID.isEmpty)
  #expect(model.content == .empty)
}

@MainActor @Test func directTabLinksSupportQueryAndFragment() {
  #expect(
    AppModel.linkedTabID(in: "https://docs.google.com/document/d/id/edit?tab=t.child") == "t.child")
  #expect(
    AppModel.linkedTabID(in: "https://docs.google.com/document/d/id/edit#tab=t.child") == "t.child")
}

@Test func malformedTabPayloadFailsInsteadOfSilentlyReturningEmpty() {
  #expect(throws: (any Error).self) { try GoogleDocTabs.decode(Data("{}".utf8)) }
}

@Test func nestedTabsKeepTheirOwnContentAndEscapeHTML() throws {
  let json = #"""
    {"tabs":[{"tabProperties":{"tabId":"t.one","title":"Experience"},"documentTab":{"body":{"content":[{"paragraph":{"elements":[{"textRun":{"content":"<script> & notes","textStyle":{"bold":true}}}]}}]}},"childTabs":[{"tabProperties":{"tabId":"t.two","title":"Projects"},"documentTab":{"body":{"content":[{"paragraph":{"elements":[{"textRun":{"content":"My project"}}]}}]}}}]}]}
    """#
  let tabs = try GoogleDocTabs.decode(Data(json.utf8))
  #expect(tabs.map(\.id) == ["t.one", "t.two"])
  #expect(tabs.map(\.depth) == [0, 1])
  #expect(tabs[0].html.contains("&lt;script&gt; &amp; notes"))
  #expect(!tabs[0].html.contains("My project"))
  #expect(tabs[1].html.contains("My project"))
}
