import Foundation
import Testing
@testable import ICloudCLICore

@Test func parsesSafariSessionWindowsAndTabs() throws {
    let plist: [String: Any] = [
        "SessionWindows": [
            [
                "TabStates": [
                    [
                        "TabURL": "https://example.com",
                        "TabTitle": "Example",
                    ],
                    [
                        "URL": "https://openclaw.ai/docs",
                        "Title": "OpenClaw Docs",
                    ],
                ],
            ],
        ],
    ]

    let tabs = SafariSessionPlistParser(sourceName: "fixture").parse(plist)

    #expect(tabs.count == 2)
    #expect(tabs[0].url == "https://example.com")
    #expect(tabs[0].title == "Example")
    #expect(tabs[0].windowIndex == 0)
    #expect(tabs[0].tabIndex == 0)
    #expect(tabs[1].url == "https://openclaw.ai/docs")
}

@Test func readerLoadsCurrentSessionPlist() throws {
    let tempRoot = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let plistURL = tempRoot.appendingPathComponent("CurrentSession.plist")
    let plist: [String: Any] = [
        "SessionWindows": [
            [
                "TabStates": [
                    [
                        "TabURL": "https://github.com/OMT-Global",
                        "TabTitle": "OMT-Global",
                    ],
                ],
            ],
        ],
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    try data.write(to: plistURL)

    let tabs = try SafariTabsReader(safariDirectory: tempRoot).readTabs(source: .currentSession)

    #expect(tabs == [
        SafariTab(
            url: "https://github.com/OMT-Global",
            title: "OMT-Global",
            windowIndex: 0,
            tabIndex: 0,
            source: "current-session"
        ),
    ])
}

@Test func readerLoadsSyntheticFixtureDirectory() throws {
    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Safari")

    let tabs = try SafariTabsReader(safariDirectory: fixtureURL).readTabs(source: .all)

    #expect(tabs == [
        SafariTab(
            url: "https://example.com/current",
            title: "Current Fixture",
            windowIndex: 0,
            tabIndex: 0,
            source: "current-session"
        ),
        SafariTab(
            url: "https://example.com/last",
            title: "Last Fixture",
            windowIndex: 0,
            tabIndex: 0,
            source: "last-session"
        ),
    ])
}

@Test func readableEmptySessionReportsNoTabsFound() throws {
    let tempRoot = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let plistURL = tempRoot.appendingPathComponent("CurrentSession.plist")
    let data = try PropertyListSerialization.data(
        fromPropertyList: ["SessionWindows": []],
        format: .xml,
        options: 0
    )
    try data.write(to: plistURL)

    #expect(throws: SafariTabsError.noTabsFound([plistURL.path])) {
        try SafariTabsReader(safariDirectory: tempRoot).readTabs(source: .currentSession)
    }
}

@Test func emptyReadableSessionPreservesUnreadableSourcePaths() throws {
    let tempRoot = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let currentSessionURL = tempRoot.appendingPathComponent("CurrentSession.plist")
    let missingLastSessionURL = tempRoot.appendingPathComponent("LastSession.plist")
    let data = try PropertyListSerialization.data(
        fromPropertyList: ["SessionWindows": []],
        format: .xml,
        options: 0
    )
    try data.write(to: currentSessionURL)

    #expect(
        throws: SafariTabsError.noTabsFoundWithUnreadableSources(
            readable: [currentSessionURL.path],
            unreadable: [missingLastSessionURL.path]
        )
    ) {
        try SafariTabsReader(safariDirectory: tempRoot).readTabs(source: .all)
    }
}

@Test func textRenderingIncludesTitleWhenPresent() throws {
    let rendered = try CommandRunner().render(
        [
            SafariTab(url: "https://example.com", title: "Example", windowIndex: 0, tabIndex: 0, source: "fixture"),
            SafariTab(url: "https://openclaw.ai", title: nil, windowIndex: 0, tabIndex: 1, source: "fixture"),
        ],
        format: .text
    )

    #expect(rendered == "Example - https://example.com\nhttps://openclaw.ai")
}

private func temporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("icloud-cli-tests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
