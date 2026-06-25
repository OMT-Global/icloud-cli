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

@Test func commandRunnerHarnessCoversDocumentedMetadataFamilies() throws {
    let fixtureRoot = testFixturesRoot()
    let tempRoot = try temporaryHarnessDirectory(named: "metadata")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let database = try syntheticFullMetadataDatabase(in: tempRoot)
    let finderTags = try syntheticFinderTagsPreferences(in: tempRoot)
    let cacheDirectory = tempRoot.appendingPathComponent("cache")
    let snapshotOutput = tempRoot.appendingPathComponent("snapshot.json")
    let sink = CommandRunnerHarnessSink()
    let runner = CommandRunner(output: { sink.appendOutput($0) }, errorOutput: { sink.appendError($0) })

    let commands: [[String]] = [
        ["icloud-cli", "snapshot", "--include", "cache-status", "--output", snapshotOutput.path, "--format", "json"],
        ["icloud-cli", "account", "status", "--cache-file", fixtureRoot.appendingPathComponent("SystemStatus/MobileMeAccounts.plist").path],
        ["icloud-cli", "backup", "status", "--cache-file", fixtureRoot.appendingPathComponent("SystemStatus/MobileMeAccounts.plist").path],
        ["icloud-cli", "family", "status", "--cache-file", fixtureRoot.appendingPathComponent("SystemStatus/MobileMeAccounts.plist").path],
        ["icloud-cli", "drive", "status", "--icloud-root", fixtureRoot.appendingPathComponent("MobileDocuments").path],
        ["icloud-cli", "drive", "errors", "--icloud-root", fixtureRoot.appendingPathComponent("MobileDocuments").path],
        ["icloud-cli", "drive", "shared", "--icloud-root", fixtureRoot.appendingPathComponent("MobileDocuments").path],
        ["icloud-cli", "drive", "recents", "--icloud-root", fixtureRoot.appendingPathComponent("MobileDocuments").path],
        ["icloud-cli", "photos", "shared-albums", "--photos-store", database.path],
        ["icloud-cli", "photos", "shared-library", "--photos-store", database.path],
        ["icloud-cli", "notes", "accounts", "--notes-store", database.path],
        ["icloud-cli", "notes", "folders", "--notes-store", database.path],
        ["icloud-cli", "notes", "tags", "--notes-store", database.path],
        ["icloud-cli", "notes", "shared", "--notes-store", database.path],
        ["icloud-cli", "reminders", "flagged", "--reminders-store", database.path],
        ["icloud-cli", "reminders", "today", "--reminders-store", database.path],
        ["icloud-cli", "reminders", "scheduled", "--reminders-store", database.path],
        ["icloud-cli", "reminders", "assigned", "--reminders-store", database.path],
        ["icloud-cli", "calendar", "accounts", "--calendar-store", database.path],
        ["icloud-cli", "calendar", "list", "--calendar-store", database.path],
        ["icloud-cli", "calendar", "events", "--calendar-store", database.path],
        ["icloud-cli", "findmy", "devices", "--findmy-store", database.path],
        ["icloud-cli", "findmy", "people", "--findmy-store", database.path],
        ["icloud-cli", "mail", "accounts", "--mail-store", database.path],
        ["icloud-cli", "mail", "mailboxes", "--mail-store", database.path],
        ["icloud-cli", "mail", "recent", "--confirm-sensitive", "--mail-store", database.path],
        ["icloud-cli", "books", "collections", "--books-store", database.path],
        ["icloud-cli", "books", "list", "--books-store", database.path],
        ["icloud-cli", "voice-memos", "list", "--voice-memos-store", database.path],
        ["icloud-cli", "home", "homes", "--home-store", database.path],
        ["icloud-cli", "home", "rooms", "--home-store", database.path],
        ["icloud-cli", "home", "accessories", "--home-store", database.path],
        ["icloud-cli", "home", "scenes", "--home-store", database.path],
        ["icloud-cli", "health", "summary", "--confirm-sensitive", "--health-store", database.path],
        ["icloud-cli", "freeform", "list", "--freeform-store", database.path],
        ["icloud-cli", "music", "status", "--music-store", database.path],
        ["icloud-cli", "music", "playlists", "--music-store", database.path],
        ["icloud-cli", "music", "tracks", "--music-store", database.path],
        ["icloud-cli", "stocks", "watchlist", "--stocks-store", database.path],
        ["icloud-cli", "stocks", "groups", "--stocks-store", database.path],
        ["icloud-cli", "weather", "favorites", "--weather-store", database.path],
        ["icloud-cli", "tags", "list", "--store", finderTags.path],
        ["icloud-cli", "tags", "items", "--tag", "report", "--icloud-root", fixtureRoot.appendingPathComponent("MobileDocuments").path],
        ["icloud-cli", "permissions", "doctor"],
        ["icloud-cli", "safari", "cloud-tabs", "list", "--confirm-sensitive", "--safari-store", database.path],
        ["icloud-cli", "safari", "profiles", "list", "--safari-store", database.path],
        ["icloud-cli", "safari", "extensions", "list", "--safari-store", database.path],
        ["icloud-cli", "watch", "--once", "--commands", "unknown-command", "--output-dir", cacheDirectory.path],
        ["icloud-cli", "cache", "read", "unknown-command", "--output-dir", cacheDirectory.path],
    ]

    for command in commands {
        #expect(runner.run(arguments: command) == 0, "Expected success for \(command.joined(separator: " "))")
    }

    #expect(FileManager.default.fileExists(atPath: snapshotOutput.path))
    #expect(sink.errors.isEmpty)
    #expect(sink.output.count == commands.count)
    #expect(sink.output.last?.contains("Unsupported cache command: unknown-command") == true)
}

@Test func driveStatusCommandIgnoresRowLimitForAggregateCounts() throws {
    let tempRoot = try temporaryHarnessDirectory(named: "drive-status-limit")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let driveRoot = tempRoot.appendingPathComponent("MobileDocuments")
    let container = driveRoot.appendingPathComponent("com~example~App")
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    try Data("ok".utf8).write(to: container.appendingPathComponent("one.txt"))
    try Data("ok".utf8).write(to: container.appendingPathComponent("two.txt"))
    try Data("ok".utf8).write(to: container.appendingPathComponent(".broken.txt.icloud"))

    let sink = CommandRunnerHarnessSink()
    let runner = CommandRunner(output: { sink.appendOutput($0) }, errorOutput: { sink.appendError($0) })

    #expect(runner.run(arguments: ["icloud-cli", "drive", "status", "--icloud-root", driveRoot.path, "--limit", "1"]) == 0)

    let output = try #require(sink.output.first)
    let summary = try JSONDecoder().decode(ICloudDriveSyncSummary.self, from: Data(output.utf8))
    #expect(summary.downloadedCount == 2)
    #expect(summary.errorCount == 1)
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

private func syntheticFullMetadataDatabase(in root: URL) throws -> URL {
    let database = try syntheticDirectInventoryDatabase(in: root)
    let sql = """
    ALTER TABLE reminders ADD COLUMN isFlagged INTEGER DEFAULT 1;
    ALTER TABLE reminders ADD COLUMN assignedToMe INTEGER DEFAULT 1;
    CREATE TABLE calendar_accounts (name TEXT, type TEXT, isEnabled INTEGER);
    INSERT INTO calendar_accounts VALUES ('iCloud', 'caldav', 1);
    CREATE TABLE calendar_calendars (account TEXT, calendar TEXT, color TEXT, isVisible INTEGER);
    INSERT INTO calendar_calendars VALUES ('iCloud', 'Work', 'blue', 1);
    CREATE TABLE calendar_events (calendar TEXT, title TEXT, startsAt TEXT, endsAt TEXT, attendees TEXT, notes TEXT);
    INSERT INTO calendar_events VALUES ('Work', 'Planning', '2026-01-01T12:00:00Z', '2026-01-01T13:00:00Z', 'alice@example.com', 'Synthetic note');
    CREATE TABLE findmy_devices (name TEXT, model TEXT, batteryLevel INTEGER, latitude REAL, longitude REAL);
    INSERT INTO findmy_devices VALUES ('Example iPhone', 'iPhone', 80, 0.0, 0.0);
    CREATE TABLE findmy_people (name TEXT, relationship TEXT, latitude REAL, longitude REAL);
    INSERT INTO findmy_people VALUES ('Example Person', 'friend', 0.0, 0.0);
    CREATE TABLE mail_accounts (account TEXT, type TEXT, mailboxCount INTEGER);
    INSERT INTO mail_accounts VALUES ('iCloud', 'IMAP', 2);
    CREATE TABLE mail_mailboxes (account TEXT, mailbox TEXT, totalCount INTEGER, unreadCount INTEGER);
    INSERT INTO mail_mailboxes VALUES ('iCloud', 'Inbox', 10, 1);
    CREATE TABLE mail_recent (account TEXT, mailbox TEXT, sender TEXT, subject TEXT, sentAt TEXT);
    INSERT INTO mail_recent VALUES ('iCloud', 'Inbox', 'sender@example.com', 'Synthetic subject', '2026-01-01T12:00:00Z');
    CREATE TABLE books_collections (collection TEXT, itemCount INTEGER);
    INSERT INTO books_collections VALUES ('Library', 1);
    CREATE TABLE books (title TEXT, author TEXT, collection TEXT, highlightCount INTEGER);
    INSERT INTO books VALUES ('Example Book', 'Example Author', 'Library', 2);
    CREATE TABLE voice_memos (title TEXT, folder TEXT, modifiedAt TEXT, durationSeconds INTEGER);
    INSERT INTO voice_memos VALUES ('Example Recording', 'All Recordings', '2026-01-01T12:00:00Z', 30);
    CREATE TABLE home_homes (home TEXT, accessoryCount INTEGER);
    INSERT INTO home_homes VALUES ('Home', 1);
    CREATE TABLE home_rooms (home TEXT, room TEXT);
    INSERT INTO home_rooms VALUES ('Home', 'Office');
    CREATE TABLE home_accessories (home TEXT, room TEXT, name TEXT, category TEXT);
    INSERT INTO home_accessories VALUES ('Home', 'Office', 'Lamp', 'Light');
    CREATE TABLE home_scenes (home TEXT, scene TEXT);
    INSERT INTO home_scenes VALUES ('Home', 'Work');
    CREATE TABLE health_summary (metric TEXT, count INTEGER, lastUpdatedAt TEXT);
    INSERT INTO health_summary VALUES ('workouts', 1, '2026-01-01T12:00:00Z');
    CREATE TABLE freeform_boards (title TEXT, folder TEXT, modifiedAt TEXT);
    INSERT INTO freeform_boards VALUES ('Example Board', 'Boards', '2026-01-01T12:00:00Z');
    CREATE TABLE music_status (metric TEXT, value TEXT);
    INSERT INTO music_status VALUES ('library', 'available');
    CREATE TABLE music_playlists (playlist TEXT, trackCount INTEGER);
    INSERT INTO music_playlists VALUES ('Example Playlist', 1);
    CREATE TABLE music_tracks (title TEXT, artist TEXT, playlist TEXT, cloudStatus TEXT);
    INSERT INTO music_tracks VALUES ('Example Track', 'Example Artist', 'Example Playlist', 'downloaded');
    CREATE TABLE stocks_watchlist (symbol TEXT, name TEXT);
    INSERT INTO stocks_watchlist VALUES ('AAPL', 'Apple Inc.');
    CREATE TABLE stocks_groups (name TEXT, symbolCount INTEGER);
    INSERT INTO stocks_groups VALUES ('Technology', 1);
    CREATE TABLE weather_favorites (name TEXT, latitude REAL, longitude REAL);
    INSERT INTO weather_favorites VALUES ('Cupertino', 0.0, 0.0);
    CREATE TABLE photos_shared_albums (title TEXT, assetCount INTEGER);
    INSERT INTO photos_shared_albums VALUES ('Shared', 1);
    CREATE TABLE photos_shared_library (status TEXT, participantCount INTEGER);
    INSERT INTO photos_shared_library VALUES ('enabled', 2);
    CREATE TABLE notes_accounts (account TEXT, folderCount INTEGER);
    INSERT INTO notes_accounts VALUES ('iCloud', 1);
    CREATE TABLE notes_folders (account TEXT, folder TEXT, noteCount INTEGER);
    INSERT INTO notes_folders VALUES ('iCloud', 'Quick Notes', 1);
    CREATE TABLE notes_tags (tag TEXT, noteCount INTEGER);
    INSERT INTO notes_tags VALUES ('project', 1);
    CREATE TABLE notes_shared (title TEXT, participantCount INTEGER);
    INSERT INTO notes_shared VALUES ('Shared Note', 2);
    CREATE TABLE cloud_tab_devices (device_uuid TEXT, device_name TEXT, last_modified TEXT);
    INSERT INTO cloud_tab_devices VALUES ('device-1', 'Example Mac', '2026-01-01T12:00:00Z');
    CREATE TABLE cloud_tabs (device_uuid TEXT, title TEXT, url TEXT, position INTEGER, is_pinned INTEGER, is_showing_reader INTEGER, scene_id TEXT);
    INSERT INTO cloud_tabs VALUES ('device-1', 'Example', 'https://example.com/private', 1, 0, 0, 'scene-1');
    CREATE TABLE safari_profiles (profile TEXT, displayName TEXT);
    INSERT INTO safari_profiles VALUES ('Default', 'Default');
    CREATE TABLE safari_extensions (profile TEXT, name TEXT, isEnabled INTEGER);
    INSERT INTO safari_extensions VALUES ('Default', 'Example Extension', 1);
    """
    try runSQLiteForCommandRunnerHarness(database: database, sql: sql)
    return database
}

private func syntheticFinderTagsPreferences(in root: URL) throws -> URL {
    let preferences = root.appendingPathComponent("finder-tags.plist")
    let plist: NSDictionary = [
        "FavoriteTagNames": ["report"],
        "TagColorDictionary": ["report": "red"],
    ]
    #expect(plist.write(to: preferences, atomically: true))
    return preferences
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
