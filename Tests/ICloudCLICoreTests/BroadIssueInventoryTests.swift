import Foundation
import Testing
@testable import ICloudCLICore

@Test func parsesBroadIssueInventoryCommands() throws {
    let samples: [([String], MetadataCommand)] = [
        (["icloud-cli", "snapshot", "--include", "storage-status,devices-list", "--redaction", "safe"], .snapshot),
        (["icloud-cli", "account", "status"], .accountStatus),
        (["icloud-cli", "backup", "status"], .backupStatus),
        (["icloud-cli", "family", "status"], .familyStatus),
        (["icloud-cli", "calendar", "accounts"], .calendarAccounts),
        (["icloud-cli", "calendar", "events", "--since", "2026-05-01", "--until", "2026-06-01", "--include-attendees"], .calendarEvents),
        (["icloud-cli", "findmy", "devices", "--include-coordinates"], .findMyDevices),
        (["icloud-cli", "findmy", "people"], .findMyPeople),
        (["icloud-cli", "mail", "recent", "--confirm-sensitive", "--limit", "5"], .mailRecent),
        (["icloud-cli", "books", "list", "--collection", "Reading", "--include-highlights"], .booksList),
        (["icloud-cli", "voice-memos", "list", "--folder", "Ideas"], .voiceMemosList),
        (["icloud-cli", "home", "accessories", "--home", "House", "--room", "Office"], .homeAccessories),
        (["icloud-cli", "health", "summary", "--confirm-sensitive"], .healthSummary),
        (["icloud-cli", "photos", "shared-albums"], .photosSharedAlbums),
        (["icloud-cli", "photos", "shared-library"], .photosSharedLibrary),
        (["icloud-cli", "safari", "cloud-tabs", "list", "--confirm-sensitive", "--include-urls"], .safariCloudTabsList),
        (["icloud-cli", "safari", "profiles", "list"], .safariProfilesList),
        (["icloud-cli", "safari", "extensions", "list", "--profile", "Work"], .safariExtensionsList),
        (["icloud-cli", "tags", "items", "--tag", "Important", "--path", "com~apple~CloudDocs"], .taggedItems),
        (["icloud-cli", "weather", "favorites", "--include-coordinates"], .weatherFavorites),
        (["icloud-cli", "stocks", "watchlist"], .stocksWatchlist),
        (["icloud-cli", "music", "tracks", "--playlist", "Focus", "--downloaded"], .musicTracks),
        (["icloud-cli", "freeform", "list", "--since", "2026-01-01"], .freeformList),
        (["icloud-cli", "permissions", "doctor"], .permissionsDoctor),
        (["icloud-cli", "drive", "status", "--path", "com~apple~CloudDocs"], .driveStatus),
        (["icloud-cli", "drive", "errors"], .driveErrors),
        (["icloud-cli", "drive", "shared"], .driveShared),
        (["icloud-cli", "drive", "recents", "--limit", "10"], .driveRecents),
        (["icloud-cli", "notes", "folders", "--account", "iCloud"], .notesFolders),
        (["icloud-cli", "notes", "tags"], .notesTags),
        (["icloud-cli", "notes", "shared"], .notesShared),
        (["icloud-cli", "reminders", "flagged", "--include-notes"], .remindersFlagged),
        (["icloud-cli", "reminders", "today"], .remindersToday),
        (["icloud-cli", "reminders", "scheduled", "--since", "2026-06-01", "--until", "2026-06-07"], .remindersScheduled),
        (["icloud-cli", "reminders", "assigned"], .remindersAssigned),
    ]

    let parser = CLIParser()
    for (arguments, expectedCommand) in samples {
        guard case .metadata(let command, _) = try parser.parse(arguments: arguments) else {
            Issue.record("Expected metadata command for \(arguments.joined(separator: " "))")
            continue
        }
        #expect(command == expectedCommand)
    }
}

@Test func driveListParsesShowStatusAndSafariParsesProfile() throws {
    let drive = try CLIParser().parse(arguments: ["icloud-cli", "drive", "list", "--show-status"])
    guard case .driveList(let driveOptions) = drive else {
        Issue.record("Expected drive list")
        return
    }
    #expect(driveOptions.showStatus == true)

    let safari = try CLIParser().parse(arguments: ["icloud-cli", "safari", "tabs", "--profile", "Work"])
    guard case .safariTabs(let safariOptions) = safari else {
        Issue.record("Expected safari tabs")
        return
    }
    #expect(safariOptions.profile == "Work")
}

@Test func readsSyntheticMetadataStoreRowsAndSensitivityGates() throws {
    let database = try syntheticBroadInventoryDatabase()
    defer { try? FileManager.default.removeItem(at: database.deletingLastPathComponent()) }
    let reader = LocalMetadataStoreReader(database: database)

    let calendars = try reader.rows(for: .calendarEvents, options: MetadataOptions(since: "2026-05-01", until: "2026-06-01"))
    #expect(calendars.map { $0.string("title") } == ["Planning"])
    #expect(calendars.first?.string("attendees") == nil)

    let mail = try reader.rows(for: .mailRecent, options: MetadataOptions(limit: 10, confirmSensitive: true))
    #expect(mail.first?.string("sender") == "sender@example.com")

    #expect(throws: LocalInventoryError.sensitiveConfirmationRequired("icloud-cli mail recent")) {
        try reader.rows(for: .mailRecent, options: MetadataOptions())
    }

    let cloudTabs = try reader.rows(for: .safariCloudTabsList, options: MetadataOptions(confirmSensitive: true, includeURLs: true))
    #expect(cloudTabs.first?.string("url") == "https://example.com")

    let health = try reader.rows(for: .healthSummary, options: MetadataOptions(confirmSensitive: true))
    #expect(health.first?.int("recordCount") == 42)
}

@Test func readsSyntheticAccountFamilyAndBackupPlists() throws {
    let plist = try syntheticAccountPlist()
    defer { try? FileManager.default.removeItem(at: plist.deletingLastPathComponent()) }

    let account = try AccountStatusReader(cacheFile: plist).readStatus()
    #expect(account.appleID == "operator@example.com")
    #expect(account.services.contains { $0.name == "Drive" && $0.enabled == true })

    let family = try FamilyStatusReader(cacheFile: plist).readStatus()
    #expect(family.configured == true)
    #expect(family.members.count == 2)

    let backups = try BackupStatusReader(cacheFile: plist).readStatus()
    #expect(backups.map(\.deviceName) == ["Example iPhone"])
    #expect(backups.first?.backupEnabled == true)
}

@Test func runsBroadInventoryCommandsThroughCommandRunner() throws {
    let database = try syntheticBroadInventoryDatabase()
    let plist = try syntheticAccountPlist()
    let tagsPlist = try syntheticTagsPlist()
    let driveRoot = try mobileDocumentsFixtureURLForBroadIssues()
    defer {
        try? FileManager.default.removeItem(at: database.deletingLastPathComponent())
        try? FileManager.default.removeItem(at: plist.deletingLastPathComponent())
        try? FileManager.default.removeItem(at: tagsPlist.deletingLastPathComponent())
    }

    let sink = BroadIssueOutputSink()
    let runner = CommandRunner(output: { sink.appendOutput($0) }, errorOutput: { sink.appendError($0) })

    let commands: [[String]] = [
        ["icloud-cli", "account", "status", "--cache-file", plist.path],
        ["icloud-cli", "backup", "status", "--cache-file", plist.path],
        ["icloud-cli", "family", "status", "--cache-file", plist.path],
        ["icloud-cli", "snapshot", "--include", "missing-command"],
        ["icloud-cli", "permissions", "doctor"],
        ["icloud-cli", "drive", "status", "--icloud-root", driveRoot.path],
        ["icloud-cli", "drive", "errors", "--icloud-root", driveRoot.path],
        ["icloud-cli", "drive", "shared", "--icloud-root", driveRoot.path],
        ["icloud-cli", "drive", "recents", "--icloud-root", driveRoot.path],
        ["icloud-cli", "tags", "list", "--store", tagsPlist.path],
        ["icloud-cli", "tags", "items", "--tag", "report", "--icloud-root", driveRoot.path],
        ["icloud-cli", "calendar", "accounts", "--store", database.path],
        ["icloud-cli", "calendar", "list", "--store", database.path],
        ["icloud-cli", "calendar", "events", "--store", database.path, "--include-attendees", "--include-notes"],
        ["icloud-cli", "findmy", "devices", "--store", database.path, "--include-coordinates"],
        ["icloud-cli", "findmy", "people", "--store", database.path, "--include-coordinates"],
        ["icloud-cli", "mail", "accounts", "--store", database.path],
        ["icloud-cli", "mail", "mailboxes", "--store", database.path],
        ["icloud-cli", "mail", "recent", "--store", database.path, "--confirm-sensitive"],
        ["icloud-cli", "books", "collections", "--store", database.path],
        ["icloud-cli", "books", "list", "--store", database.path, "--include-highlights"],
        ["icloud-cli", "voice-memos", "list", "--store", database.path],
        ["icloud-cli", "home", "homes", "--store", database.path],
        ["icloud-cli", "home", "rooms", "--store", database.path],
        ["icloud-cli", "home", "accessories", "--store", database.path],
        ["icloud-cli", "home", "scenes", "--store", database.path],
        ["icloud-cli", "health", "summary", "--store", database.path, "--confirm-sensitive"],
        ["icloud-cli", "photos", "shared-albums", "--store", database.path],
        ["icloud-cli", "photos", "shared-library", "--store", database.path],
        ["icloud-cli", "safari", "cloud-tabs", "list", "--store", database.path, "--confirm-sensitive", "--include-urls"],
        ["icloud-cli", "safari", "profiles", "list", "--store", database.path],
        ["icloud-cli", "safari", "extensions", "list", "--store", database.path],
        ["icloud-cli", "weather", "favorites", "--store", database.path, "--include-coordinates"],
        ["icloud-cli", "stocks", "watchlist", "--store", database.path],
        ["icloud-cli", "stocks", "groups", "--store", database.path],
        ["icloud-cli", "music", "status", "--store", database.path],
        ["icloud-cli", "music", "playlists", "--store", database.path],
        ["icloud-cli", "music", "tracks", "--store", database.path, "--downloaded"],
        ["icloud-cli", "freeform", "list", "--store", database.path],
        ["icloud-cli", "notes", "accounts", "--store", database.path],
        ["icloud-cli", "notes", "folders", "--store", database.path],
        ["icloud-cli", "notes", "tags", "--store", database.path],
        ["icloud-cli", "notes", "shared", "--store", database.path],
        ["icloud-cli", "reminders", "flagged", "--store", database.path, "--include-notes"],
        ["icloud-cli", "reminders", "scheduled", "--store", database.path, "--since", "2026-01-01", "--until", "2026-12-31"],
        ["icloud-cli", "reminders", "assigned", "--store", database.path],
    ]

    for command in commands {
        #expect(runner.run(arguments: command) == 0)
    }
    #expect(sink.errors.isEmpty)
    #expect(sink.output.count == commands.count)
}

@Test func reportsDriveStatusAndRecentFilesFromFixture() throws {
    let reader = ICloudDriveInventoryReader(rootDirectory: try mobileDocumentsFixtureURLForBroadIssues())

    let summary = try reader.syncStatus(path: nil)
    #expect(summary.downloadedCount > 0)
    #expect(summary.cloudOnlyCount > 0)

    let recents = try reader.recentFiles(since: nil, limit: 5)
    #expect(recents.isEmpty == false)
}

private func syntheticBroadInventoryDatabase() throws -> URL {
    let root = try temporaryDirectoryForBroadIssues(named: "broad-sqlite")
    let database = root.appendingPathComponent("inventory.sqlite")
    let sql = """
    CREATE TABLE calendar_events (title TEXT, calendar TEXT, startsAt TEXT, endsAt TEXT, isAllDay INTEGER, attendees TEXT, notes TEXT);
    INSERT INTO calendar_events VALUES ('Planning', 'Work', '2026-05-10T09:00:00Z', '2026-05-10T10:00:00Z', 0, 'teammate@example.com', 'private');
    CREATE TABLE calendar_accounts (name TEXT, type TEXT, calendarCount INTEGER);
    INSERT INTO calendar_accounts VALUES ('iCloud', 'iCloud', 1);
    CREATE TABLE calendar_calendars (title TEXT, account TEXT, color TEXT, source TEXT, isDefault INTEGER);
    INSERT INTO calendar_calendars VALUES ('Work', 'iCloud', 'blue', 'CalDAV', 1);
    CREATE TABLE findmy_devices (name TEXT, model TEXT, onlineStatus TEXT, lastSeenAt TEXT, batteryLevel INTEGER, charging INTEGER, latitude REAL, longitude REAL);
    INSERT INTO findmy_devices VALUES ('Example iPhone', 'iPhone', 'online', '2026-05-10T09:00:00Z', 80, 0, 1.0, 2.0);
    CREATE TABLE findmy_people (name TEXT, lastUpdatedAt TEXT, sharingDirection TEXT, latitude REAL, longitude REAL);
    INSERT INTO findmy_people VALUES ('Example Person', '2026-05-10T09:00:00Z', 'with-me', 1.0, 2.0);
    CREATE TABLE mail_accounts (displayName TEXT, type TEXT);
    INSERT INTO mail_accounts VALUES ('iCloud Mail', 'iCloud');
    CREATE TABLE mail_mailboxes (account TEXT, mailbox TEXT, totalCount INTEGER, unreadCount INTEGER);
    INSERT INTO mail_mailboxes VALUES ('iCloud Mail', 'Inbox', 2, 1);
    CREATE TABLE mail_recent (sender TEXT, subject TEXT, sentAt TEXT, mailbox TEXT);
    INSERT INTO mail_recent VALUES ('sender@example.com', 'Hello', '2026-05-10T09:00:00Z', 'Inbox');
    CREATE TABLE books_collections (name TEXT, bookCount INTEGER);
    INSERT INTO books_collections VALUES ('Reading', 1);
    CREATE TABLE books (title TEXT, author TEXT, format TEXT, collection TEXT, progressPercent INTEGER, highlightCount INTEGER);
    INSERT INTO books VALUES ('Example Book', 'Example Author', 'epub', 'Reading', 50, 2);
    CREATE TABLE voice_memos (title TEXT, folder TEXT, durationSeconds INTEGER, modifiedAt TEXT, sizeBytes INTEGER, favorite INTEGER);
    INSERT INTO voice_memos VALUES ('Idea', 'Ideas', 30, '2026-05-10T09:00:00Z', 100, 1);
    CREATE TABLE home_homes (name TEXT, primaryFlag INTEGER);
    INSERT INTO home_homes VALUES ('House', 1);
    CREATE TABLE home_rooms (home TEXT, name TEXT, accessoryCount INTEGER);
    INSERT INTO home_rooms VALUES ('House', 'Office', 1);
    CREATE TABLE home_accessories (home TEXT, room TEXT, name TEXT, manufacturer TEXT, model TEXT, category TEXT, bridged INTEGER);
    INSERT INTO home_accessories VALUES ('House', 'Office', 'Lamp', 'Example', 'A1', 'light', 0);
    CREATE TABLE home_scenes (home TEXT, name TEXT, accessoryCount INTEGER);
    INSERT INTO home_scenes VALUES ('House', 'Work', 1);
    CREATE TABLE cloud_tab_devices (device_uuid TEXT PRIMARY KEY, system_fields BLOB, device_name TEXT, has_duplicate_device_name INTEGER, is_ephemeral_device INTEGER, last_modified TEXT);
    CREATE TABLE cloud_tabs (tab_uuid TEXT PRIMARY KEY, system_fields BLOB, device_uuid TEXT, position INTEGER, title TEXT, url TEXT, is_showing_reader INTEGER, is_pinned INTEGER, reader_scroll_position_page_index INTEGER, scene_id TEXT);
    INSERT INTO cloud_tab_devices VALUES ('device-1', NULL, 'Example iPhone', 0, 0, '2026-05-10T09:00:00Z');
    INSERT INTO cloud_tabs VALUES ('tab-1', NULL, 'device-1', 1, 'Example Page', 'https://example.com/private/path', 0, 0, NULL, 'scene-1');
    CREATE TABLE safari_profiles (name TEXT, identifier TEXT, isDefault INTEGER, tabCount INTEGER, bookmarkCount INTEGER, lastActiveAt TEXT);
    INSERT INTO safari_profiles VALUES ('Work', 'work', 0, 1, 2, '2026-05-10T09:00:00Z');
    CREATE TABLE safari_extensions (profile TEXT, bundleID TEXT, displayName TEXT, enabled INTEGER, type TEXT);
    INSERT INTO safari_extensions VALUES ('Work', 'com.example.extension', 'Example Extension', 1, 'web-extension');
    CREATE TABLE health_summary (type TEXT, recordCount INTEGER, oldestAt TEXT, newestAt TEXT, sources TEXT);
    INSERT INTO health_summary VALUES ('steps', 42, '2026-01-01T00:00:00Z', '2026-05-10T00:00:00Z', 'com.example.watch');
    CREATE TABLE photos_shared_albums (title TEXT, owner TEXT, collaboratorCount INTEGER, assetCount INTEGER, updatedAt TEXT);
    INSERT INTO photos_shared_albums VALUES ('Trip', 'me', 2, 10, '2026-05-10T09:00:00Z');
    CREATE TABLE photos_shared_library (enabled INTEGER, participantCount INTEGER, contributionSetting TEXT);
    INSERT INTO photos_shared_library VALUES (1, 2, 'manual');
    CREATE TABLE weather_favorites (name TEXT, locality TEXT, region TEXT, country TEXT, latitude REAL, longitude REAL);
    INSERT INTO weather_favorites VALUES ('Example City', 'Example', 'CA', 'US', 1.0, 2.0);
    CREATE TABLE stocks_watchlist (symbol TEXT, displayName TEXT, exchange TEXT, displayOrder INTEGER);
    INSERT INTO stocks_watchlist VALUES ('EXM', 'Example Inc', 'NASDAQ', 1);
    CREATE TABLE stocks_groups (name TEXT, tickerCount INTEGER);
    INSERT INTO stocks_groups VALUES ('Main', 1);
    CREATE TABLE music_status (icloudMusicLibraryEnabled INTEGER, subscriptionState TEXT, trackCount INTEGER, playlistCount INTEGER);
    INSERT INTO music_status VALUES (1, 'active', 1, 1);
    CREATE TABLE music_playlists (name TEXT, kind TEXT, trackCount INTEGER, shared INTEGER);
    INSERT INTO music_playlists VALUES ('Focus', 'user', 1, 0);
    CREATE TABLE music_tracks (title TEXT, artist TEXT, album TEXT, playlist TEXT, cloudStatus TEXT);
    INSERT INTO music_tracks VALUES ('Example Song', 'Example Artist', 'Example Album', 'Focus', 'downloaded');
    CREATE TABLE freeform_boards (title TEXT, folder TEXT, modifiedAt TEXT, collaboratorCount INTEGER, shared INTEGER, thumbnailPresent INTEGER);
    INSERT INTO freeform_boards VALUES ('Board', 'Ideas', '2026-05-10T09:00:00Z', 0, 0, 1);
    CREATE TABLE notes_accounts (name TEXT, type TEXT, folderCount INTEGER, noteCount INTEGER);
    INSERT INTO notes_accounts VALUES ('iCloud', 'iCloud', 1, 1);
    CREATE TABLE notes_folders (name TEXT, account TEXT, parentFolder TEXT, smartFolder INTEGER, noteCount INTEGER, shared INTEGER);
    INSERT INTO notes_folders VALUES ('Quick Notes', 'iCloud', NULL, 0, 1, 0);
    CREATE TABLE notes_tags (name TEXT, noteCount INTEGER);
    INSERT INTO notes_tags VALUES ('project', 1);
    CREATE TABLE notes_shared (title TEXT, ownerRole TEXT, participantCount INTEGER);
    INSERT INTO notes_shared VALUES ('Shared Plan', 'owner', 2);
    CREATE TABLE reminders (title TEXT, listName TEXT, dueAt TEXT, isCompleted INTEGER, priority INTEGER, notes TEXT, isFlagged INTEGER, assignedToMe INTEGER);
    INSERT INTO reminders VALUES ('Ship PR', 'Work', '2026-05-16T12:00:00Z', 0, 5, 'Review', 1, 1);
    """
    try runSQLiteForBroadIssues(database: database, sql: sql)
    return database
}

private func syntheticAccountPlist() throws -> URL {
    let root = try temporaryDirectoryForBroadIssues(named: "account-plist")
    let plist = root.appendingPathComponent("MobileMeAccounts.plist")
    let data: NSDictionary = [
        "AccountID": "operator@example.com",
        "AccountType": "iCloud",
        "twoFactorEnabled": true,
        "advancedDataProtectionEnabled": false,
        "Services": [
            ["Name": "Drive", "Enabled": true],
            ["Name": "Photos", "Enabled": false],
        ],
        "Family": [
            "configured": true,
            "organizer": "operator@example.com",
            "members": [
                ["displayName": "Operator", "role": "organizer", "email": "operator@example.com", "purchaseSharing": true],
                ["displayName": "Example Child", "role": "child", "email": "child@example.com", "purchaseSharing": false],
            ],
            "subscriptions": [
                ["name": "iCloud+", "tier": "2 TB"],
            ],
        ],
        "Backups": [
            ["deviceName": "Example iPhone", "model": "iPhone", "backupEnabled": true, "lastBackupAt": "2026-05-01T00:00:00Z", "backupSizeBytes": 1234],
        ],
    ]
    data.write(to: plist, atomically: true)
    return plist
}

private func syntheticTagsPlist() throws -> URL {
    let root = try temporaryDirectoryForBroadIssues(named: "tags-plist")
    let plist = root.appendingPathComponent("com.apple.finder.plist")
    let data: NSDictionary = [
        "FavoriteTagNames": ["Important"],
        "TagColorDictionary": ["Important": "red"],
    ]
    data.write(to: plist, atomically: true)
    return plist
}

private func mobileDocumentsFixtureURLForBroadIssues() throws -> URL {
    let fileURL = URL(fileURLWithPath: #filePath)
    let testsDirectory = fileURL.deletingLastPathComponent().deletingLastPathComponent()
    return testsDirectory.appendingPathComponent("Fixtures/MobileDocuments")
}

private func runSQLiteForBroadIssues(database: URL, sql: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [database.path, sql]
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
}

private func temporaryDirectoryForBroadIssues(named name: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("icloud-cli-tests")
        .appendingPathComponent(name)
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

private final class BroadIssueOutputSink: @unchecked Sendable {
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
