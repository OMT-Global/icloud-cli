import Foundation
import Testing
@testable import ICloudCLICore

@Test func readsSafariBookmarksFixture() throws {
    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Safari")

    let bookmarks = try SafariBookmarksReader(safariDirectory: fixtureURL).readBookmarks()

    #expect(bookmarks == [
        SafariBookmark(title: "Example Docs", url: "https://example.com/docs", folderPath: "BookmarksBar"),
        SafariBookmark(title: "Example Research", url: "https://example.org/research", folderPath: "BookmarksBar/Research"),
    ])
}

@Test func readsSafariReadingListFixture() throws {
    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Safari")

    let items = try SafariBookmarksReader(safariDirectory: fixtureURL).readReadingList()

    #expect(items == [
        SafariReadingListItem(
            title: "Read Later",
            url: "https://example.net/read",
            addedAt: "2026-05-13T00:00:00Z",
            lastVisitedAt: nil,
            isRead: nil
        ),
    ])
}

@Test func readsSafariFrequentlyVisitedFixture() throws {
    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Safari")

    let sites = try SafariFrequentlyVisitedReader(safariDirectory: fixtureURL).readSites(limit: 1)

    #expect(sites == [
        SafariFrequentlyVisitedSite(title: "Dashboard", url: "https://example.com/dashboard", rank: 1),
    ])
}

@Test func rendersSafariFrequentlyVisitedText() throws {
    let rendered = try CommandRunner().render(
        [SafariFrequentlyVisitedSite(title: "Dashboard", url: "https://example.com/dashboard", rank: 1)],
        format: .text
    )

    #expect(rendered == "#1 Dashboard - https://example.com/dashboard")
}
