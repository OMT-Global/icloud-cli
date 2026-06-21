import Foundation
import Testing
@testable import ICloudCLICore

@Test func commandRunnerHarnessCoversDirectCommandFamilies() throws {
    let fixtureRoot = testFixturesRoot()
    let tempRoot = try temporaryHarnessDirectory(named: "direct")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let media = try syntheticMediaFixture(in: tempRoot)
    let database = try syntheticDirectInventoryDatabase(in: tempRoot)
    let cacheDirectory = tempRoot.appendingPathComponent("cache")
    let sink = CommandRunnerHarnessSink()
    let runner = CommandRunner(output: { sink.appendOutput($0) }, errorOutput: { sink.appendError($0) })

    let commands: [[String]] = [
        ["icloud-cli", "--help"],
        ["icloud-cli", "--version"],
        ["icloud-cli", "storage", "status", "--cache-file", fixtureRoot.appendingPathComponent("SystemStatus/MobileMeAccounts.plist").path],
        ["icloud-cli", "focus", "status", "--focus-dir", fixtureRoot.appendingPathComponent("SystemStatus/Focus").path],
        ["icloud-cli", "devices", "list", "--cache-file", fixtureRoot.appendingPathComponent("SystemStatus/MobileMeAccounts.plist").path],
        ["icloud-cli", "wallet", "passes", "--passes-dir", fixtureRoot.appendingPathComponent("Wallet").path],
        ["icloud-cli", "handoff", "list", "--handoff-dir", fixtureRoot.appendingPathComponent("Handoff").path],
        ["icloud-cli", "drive", "list", "--icloud-root", fixtureRoot.appendingPathComponent("MobileDocuments").path],
        ["icloud-cli", "drive", "containers", "--icloud-root", fixtureRoot.appendingPathComponent("MobileDocuments").path],
        ["icloud-cli", "shortcuts", "list", "--shortcuts-dir", fixtureRoot.appendingPathComponent("Shortcuts").path],
        ["icloud-cli", "photos", "screenshots", "--screenshots-dir", media.screenshots.path],
        ["icloud-cli", "photos", "list", "--photos-library", media.photosLibrary.path],
        ["icloud-cli", "notes", "list", "--notes-store", database.path],
        ["icloud-cli", "reminders", "lists", "--reminders-store", database.path],
        ["icloud-cli", "reminders", "list", "--reminders-store", database.path],
        ["icloud-cli", "safari", "history", "--confirm-sensitive", "--history-db", database.path],
        ["icloud-cli", "messages", "conversations", "--chat-db", database.path],
        ["icloud-cli", "messages", "recent", "--confirm-sensitive", "--chat-db", database.path],
        ["icloud-cli", "contacts", "list", "--addressbook-db", database.path],
        ["icloud-cli", "maps", "favorites", "--maps-store", database.path],
        ["icloud-cli", "maps", "recents", "--maps-store", database.path],
        ["icloud-cli", "news", "history", "--news-store", database.path],
        ["icloud-cli", "news", "topics", "--news-store", database.path],
        ["icloud-cli", "safari", "tabs", "--safari-dir", fixtureRoot.appendingPathComponent("Safari").path],
        ["icloud-cli", "safari", "bookmarks", "--safari-dir", fixtureRoot.appendingPathComponent("Safari").path],
        ["icloud-cli", "safari", "reading-list", "--safari-dir", fixtureRoot.appendingPathComponent("Safari").path],
        ["icloud-cli", "safari", "frequently-visited", "--safari-dir", fixtureRoot.appendingPathComponent("Safari").path],
        ["icloud-cli", "safari", "cloud-tabs", "probe", "--safari-dir", fixtureRoot.appendingPathComponent("Safari").path],
        ["icloud-cli", "watch", "--once", "--commands", "unknown-command", "--output-dir", cacheDirectory.path],
        ["icloud-cli", "cache", "status", "--output-dir", cacheDirectory.path],
        ["icloud-cli", "cache", "read", "unknown-command", "--output-dir", cacheDirectory.path],
    ]

    for command in commands {
        #expect(runner.run(arguments: command) == 0, "Expected success for \(command.joined(separator: " "))")
    }

    #expect(sink.errors.isEmpty)
    #expect(sink.output.count == commands.count)
    #expect(sink.output[0].contains("Created by OMT-Global."))
    #expect(sink.output[1] == CLIHelp.version)
}

@Test func commandRunnerHarnessReportsExpectedSafetyAndStoreFailures() throws {
    let database = try syntheticDirectInventoryDatabase(in: try temporaryHarnessDirectory(named: "failures"))
    defer { try? FileManager.default.removeItem(at: database.deletingLastPathComponent()) }

    let sink = CommandRunnerHarnessSink()
    let runner = CommandRunner(output: { sink.appendOutput($0) }, errorOutput: { sink.appendError($0) })

    let failures: [[String]] = [
        ["icloud-cli", "safari", "history", "--history-db", database.path],
        ["icloud-cli", "messages", "recent", "--chat-db", database.path],
        ["icloud-cli", "cache", "read", "missing", "--output-dir", database.deletingLastPathComponent().appendingPathComponent("cache").path],
    ]

    for command in failures {
        #expect(runner.run(arguments: command) == 1, "Expected failure for \(command.joined(separator: " "))")
    }

    #expect(sink.output.isEmpty)
    #expect(sink.errors.count == failures.count)
    #expect(sink.errors[0].contains("--confirm-sensitive"))
    #expect(sink.errors[1].contains("--confirm-sensitive"))
    #expect(sink.errors[2].contains("No cached output found"))
}

private func testFixturesRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
}

private func syntheticMediaFixture(in root: URL) throws -> (screenshots: URL, photosLibrary: URL) {
    let screenshots = root.appendingPathComponent("Screenshots")
    let photosLibrary = root.appendingPathComponent("Photos.photoslibrary")
    try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: photosLibrary.appendingPathComponent("originals"), withIntermediateDirectories: true)
    try Data("synthetic".utf8).write(to: screenshots.appendingPathComponent("Screen Shot.png"))
    try Data("synthetic".utf8).write(to: photosLibrary.appendingPathComponent("originals/IMG_0001.HEIC"))
    return (screenshots, photosLibrary)
}

private func syntheticDirectInventoryDatabase(in root: URL) throws -> URL {
    let database = root.appendingPathComponent("direct-inventory.sqlite")
    let sql = """
    CREATE TABLE notes (title TEXT, folderName TEXT, createdAt TEXT, modifiedAt TEXT, isPinned INTEGER, body TEXT);
    INSERT INTO notes VALUES ('Plan', 'Quick Notes', '2026-01-01T00:00:00Z', '2026-01-02T00:00:00Z', 1, 'Sensitive body');
    CREATE TABLE reminders (title TEXT, listName TEXT, dueAt TEXT, isCompleted INTEGER, priority INTEGER, notes TEXT, createdAt TEXT);
    INSERT INTO reminders VALUES ('Ship PR', 'Work', '2026-05-16T12:00:00Z', 0, 5, 'Review', '2026-05-15T00:00:00Z');
    CREATE TABLE safari_history (url TEXT, title TEXT, visitedAt TEXT, visitCount INTEGER);
    INSERT INTO safari_history VALUES ('https://example.com/private/path', 'Example', '2026-05-16T12:00:00Z', 2);
    CREATE TABLE message_conversations (chatIdentifier TEXT, displayName TEXT, participantCount INTEGER, lastMessageAt TEXT, messageCount INTEGER);
    INSERT INTO message_conversations VALUES ('chat-1', 'Example Chat', 2, '2026-05-16T12:00:00Z', 3);
    CREATE TABLE recent_messages (chatIdentifier TEXT, sender TEXT, sentAt TEXT, isFromMe INTEGER, body TEXT);
    INSERT INTO recent_messages VALUES ('chat-1', 'alice@example.com', '2026-05-16T12:00:00Z', 0, 'hello');
    CREATE TABLE contacts (displayName TEXT, givenName TEXT, familyName TEXT, organizationName TEXT, emails TEXT, phones TEXT, note TEXT);
    INSERT INTO contacts VALUES ('Alice Example', 'Alice', 'Example', 'Example Org', 'work:alice@example.com', 'mobile:+15550101', 'private note');
    CREATE TABLE map_favorites (name TEXT, address TEXT, latitude REAL, longitude REAL, category TEXT);
    INSERT INTO map_favorites VALUES ('Example Home', '1 Example Way', 0.0, 0.0, 'home');
    CREATE TABLE map_recents (name TEXT, address TEXT, latitude REAL, longitude REAL, category TEXT, searchedAt TEXT);
    INSERT INTO map_recents VALUES ('Example Cafe', '2 Example Way', 0.0, 0.0, 'restaurant', '2026-05-16T12:00:00Z');
    CREATE TABLE news_history (title TEXT, source TEXT, url TEXT, readAt TEXT, topic TEXT);
    INSERT INTO news_history VALUES ('Example Article', 'Example News', 'https://example.com/news', '2026-05-16T12:00:00Z', 'Technology');
    CREATE TABLE news_topics (name TEXT, type TEXT);
    INSERT INTO news_topics VALUES ('Technology', 'topic');
    """
    try runSQLiteForCommandRunnerHarness(database: database, sql: sql)
    return database
}

private func runSQLiteForCommandRunnerHarness(database: URL, sql: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [database.path, sql]
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
}

private func temporaryHarnessDirectory(named name: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("icloud-cli-tests")
        .appendingPathComponent(name)
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private final class CommandRunnerHarnessSink: @unchecked Sendable {
    private let lock = NSLock()
    private var capturedOutput: [String] = []
    private var capturedErrors: [String] = []

    var output: [String] {
        lock.withLock { capturedOutput }
    }

    var errors: [String] {
        lock.withLock { capturedErrors }
    }

    func appendOutput(_ value: String) {
        lock.withLock { capturedOutput.append(value) }
    }

    func appendError(_ value: String) {
        lock.withLock { capturedErrors.append(value) }
    }
}
