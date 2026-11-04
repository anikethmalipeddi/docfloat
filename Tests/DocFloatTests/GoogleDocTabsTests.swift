import Foundation
import Testing

@testable import DocFloat

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
