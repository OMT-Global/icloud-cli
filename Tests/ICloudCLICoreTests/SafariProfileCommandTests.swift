import Foundation
import Testing
@testable import ICloudCLICore

@Test func safariProfileCommandsReadProfileScopedStores() throws {
    let root = try temporarySafariProfileDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let profile = root.appendingPathComponent("Profiles/Work")
    try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)

    try writeSession(url: "https://example.com/default-tab", title: "Default Tab", to: root.appendingPathComponent("CurrentSession.plist"))
    try writeSession(url: "https://example.com/work-tab", title: "Work Tab", to: profile.appendingPathComponent("CurrentSession.plist"))
    try writeBookmarks(url: "https://example.com/default-bookmark", readingListURL: "https://example.com/default-reading", to: root.appendingPathComponent("Bookmarks.plist"))
    try writeBookmarks(url: "https://example.com/work-bookmark", readingListURL: "https://example.com/work-reading", to: profile.appendingPathComponent("Bookmarks.plist"))
    try writeTopSites(url: "https://example.com/default-top", to: root.appendingPathComponent("TopSites.plist"))
    try writeTopSites(url: "https://example.com/work-top", to: profile.appendingPathComponent("TopSites.plist"))
    try writeHistory(url: "https://example.com/default-history", to: root.appendingPathComponent("History.db"))
    try writeHistory(url: "https://example.com/work-history", to: profile.appendingPathComponent("History.db"))

    #expect(try renderedURLs(arguments: ["icloud-cli", "safari", "tabs", "--source", "current-session", "--profile", "Work", "--safari-dir", root.path]) == ["https://example.com/work-tab"])
    #expect(try renderedURLs(arguments: ["icloud-cli", "safari", "bookmarks", "--profile", "Work", "--safari-dir", root.path]) == ["https://example.com/work-bookmark"])
    #expect(try renderedURLs(arguments: ["icloud-cli", "safari", "reading-list", "--profile", "Work", "--safari-dir", root.path]) == ["https://example.com/work-reading"])
    #expect(try renderedURLs(arguments: ["icloud-cli", "safari", "frequently-visited", "--profile", "Work", "--safari-dir", root.path]) == ["https://example.com/work-top"])
    #expect(try renderedURLs(arguments: ["icloud-cli", "safari", "history", "--confirm-sensitive", "--since", "2026-01-01T00:00:00Z", "--profile", "Work", "--history-db", root.appendingPathComponent("History.db").path]) == ["https://example.com/work-history"])
}

@Test func safariProfileAllKeepsDefaultSafariDirectory() throws {
    let root = try temporarySafariProfileDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let profile = root.appendingPathComponent("Profiles/Work")
    try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
    try writeSession(url: "https://example.com/default-tab", title: "Default Tab", to: root.appendingPathComponent("CurrentSession.plist"))
    try writeSession(url: "https://example.com/work-tab", title: "Work Tab", to: profile.appendingPathComponent("CurrentSession.plist"))

    #expect(try renderedURLs(arguments: ["icloud-cli", "safari", "tabs", "--source", "current-session", "--profile", "all", "--safari-dir", root.path]) == ["https://example.com/default-tab"])
}

private func renderedURLs(arguments: [String]) throws -> [String] {
    let sink = SafariProfileOutputSink()
    let exitCode = CommandRunner(output: { sink.appendOutput($0) }, errorOutput: { sink.appendError($0) }).run(arguments: arguments)
    #expect(exitCode == 0)
    #expect(sink.errors.isEmpty)
    let data = Data(sink.output.joined(separator: "\n").utf8)
    let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    return rows?.compactMap { $0["url"] as? String } ?? []
}

private func writeSession(url: String, title: String, to fileURL: URL) throws {
    let plist: [String: Any] = [
        "SessionWindows": [
            [
                "TabStates": [
                    [
                        "TabURL": url,
                        "TabTitle": title,
                    ],
                ],
            ],
        ],
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: fileURL)
}

private func writeBookmarks(url: String, readingListURL: String, to fileURL: URL) throws {
    let plist: [String: Any] = [
        "Children": [
            [
                "WebBookmarkType": "WebBookmarkTypeLeaf",
                "URLString": url,
                "Title": "Bookmark",
            ],
            [
                "WebBookmarkType": "WebBookmarkTypeList",
                "Title": "Reading List",
                "Children": [
                    [
                        "WebBookmarkType": "WebBookmarkTypeLeaf",
                        "URLString": readingListURL,
                        "Title": "Reading",
                    ],
                ],
            ],
        ],
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: fileURL)
}

private func writeTopSites(url: String, to fileURL: URL) throws {
    let plist: [String: Any] = [
        "TopSites": [
            [
                "URL": url,
                "Title": "Top Site",
                "Score": 1,
            ],
        ],
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: fileURL)
}

private func writeHistory(url: String, to database: URL) throws {
    let sql = """
    CREATE TABLE safari_history (url TEXT, title TEXT, visitedAt TEXT, visitCount INTEGER);
    INSERT INTO safari_history VALUES ('\(url)', 'History', '2026-05-10T09:00:00Z', 1);
    """
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [database.path, sql]
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
}

private func temporarySafariProfileDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("icloud-cli-tests")
        .appendingPathComponent("safari-profiles")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private final class SafariProfileOutputSink: @unchecked Sendable {
    private let lock = NSLock()
    private var capturedOutput: [String] = []
    private var capturedErrors: [String] = []

    var output: [String] { lock.withLock { capturedOutput } }
    var errors: [String] { lock.withLock { capturedErrors } }

    func appendOutput(_ value: String) {
        lock.withLock { capturedOutput.append(value) }
    }

    func appendError(_ value: String) {
        lock.withLock { capturedErrors.append(value) }
    }
}
