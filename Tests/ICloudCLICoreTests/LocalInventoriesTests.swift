import Foundation
import Testing
@testable import ICloudCLICore

@Test func parsesOpenIssueInventoryCommands() throws {
    let photos = try CLIParser().parse(arguments: ["icloud-cli", "photos", "screenshots", "--screenshots-dir", "/tmp/screenshots", "--format", "text"])
    guard case .photosScreenshots(let photoOptions) = photos else {
        Issue.record("Expected photos screenshots command")
        return
    }
    #expect(photoOptions.screenshotsDirectory.path == "/tmp/screenshots")
    #expect(photoOptions.format == .text)

    let notes = try CLIParser().parse(arguments: ["icloud-cli", "notes", "list", "--folder", "Quick Notes", "--modified-since", "2026-01-01T00:00:00Z", "--include-body", "--notes-store", "/tmp/notes.sqlite"])
    guard case .notesList(let notesOptions) = notes else {
        Issue.record("Expected notes list command")
        return
    }
    #expect(notesOptions.folder == "Quick Notes")
    #expect(notesOptions.includeBody == true)
    #expect(notesOptions.notesStore.path == "/tmp/notes.sqlite")

    let safari = try CLIParser().parse(arguments: ["icloud-cli", "safari", "history", "--confirm-sensitive", "--redact-urls", "--history-db", "/tmp/history.db"])
    guard case .safariHistory(let safariOptions) = safari else {
        Issue.record("Expected safari history command")
        return
    }
    #expect(safariOptions.confirmSensitive == true)
    #expect(safariOptions.redactURLs == true)

    let messages = try CLIParser().parse(arguments: ["icloud-cli", "messages", "conversations", "--limit", "5", "--chat-db", "/tmp/chat.db"])
    guard case .messagesConversations(let messagesOptions) = messages else {
        Issue.record("Expected messages conversations command")
        return
    }
    #expect(messagesOptions.limit == 5)
    #expect(messagesOptions.chatDatabase.path == "/tmp/chat.db")

    let watch = try CLIParser().parse(arguments: ["icloud-cli", "watch", "--once", "--commands", "safari-tabs,storage-status", "--output-dir", "/tmp/cache"])
    guard case .watch(let watchOptions) = watch else {
        Issue.record("Expected watch command")
        return
    }
    #expect(watchOptions.once == true)
    #expect(watchOptions.commands == ["safari-tabs", "storage-status"])
}

@Test func readsScreenshotAndPhotoMetadataFromSyntheticFiles() throws {
    let root = try temporaryDirectory(named: "media")
    defer { try? FileManager.default.removeItem(at: root) }
    let screenshots = root.appendingPathComponent("Screenshots")
    let photos = root.appendingPathComponent("Photos.photoslibrary")
    try FileManager.default.createDirectory(at: screenshots, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: photos.appendingPathComponent("originals"), withIntermediateDirectories: true)
    try Data("synthetic".utf8).write(to: screenshots.appendingPathComponent("Screen Shot.png"))
    try Data("synthetic".utf8).write(to: photos.appendingPathComponent("originals/IMG_0001.HEIC"))

    let reader = PhotosInventoryReader(screenshotsDirectory: screenshots, photosLibraryDirectory: photos)

    #expect(try reader.listScreenshots().map(\.mimeType) == ["image/png"])
    #expect(try reader.listPhotos().map(\.mediaType) == ["photo"])
}

@Test func limitsSyntheticPhotoInventoryWalks() throws {
    let root = try temporaryDirectory(named: "media-limit")
    defer { try? FileManager.default.removeItem(at: root) }
    let photos = root.appendingPathComponent("Photos.photoslibrary/originals")
    try FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
    try Data("one".utf8).write(to: photos.appendingPathComponent("IMG_0001.HEIC"))
    try Data("two".utf8).write(to: photos.appendingPathComponent("IMG_0002.HEIC"))

    let reader = PhotosInventoryReader(photosLibraryDirectory: root.appendingPathComponent("Photos.photoslibrary"))

    #expect(try reader.listPhotos(limit: 1).count == 1)
}

@Test func mapsSQLiteAuthorizationDeniedToPermissionError() {
    let error = sqliteError(from: Data("Error: unable to open database \"/tmp/private.sqlite\": authorization denied".utf8), store: "/tmp/private.sqlite")

    #expect(error == .permissionDenied("/tmp/private.sqlite"))
    #expect(error.localizedDescription.contains("Full Disk Access"))
}

@Test func readsSyntheticSQLiteInventoriesAndSensitiveGates() throws {
    let database = try syntheticInventoryDatabase()
    defer { try? FileManager.default.removeItem(at: database.deletingLastPathComponent()) }
    let reader = LocalSQLiteInventoryReader(database: database)

    let notes = try reader.notes(folder: "Quick Notes", modifiedSince: nil, includeBody: false)
    #expect(notes.map(\.title) == ["Plan"])
    #expect(notes.first?.body == nil)

    let reminders = try reader.reminders(list: "Work", dueBefore: "2026-12-31T00:00:00Z", dueAfter: nil, includeCompleted: false)
    #expect(reminders.map(\.title) == ["Ship PR"])
    #expect(try reader.reminderLists().first?.itemCount == 1)

    #expect(throws: LocalInventoryError.sensitiveConfirmationRequired("icloud-cli safari history")) {
        try reader.safariHistory(confirmSensitive: false, since: nil, until: nil, limit: 10, redactURLs: false)
    }
    let history = try reader.safariHistory(confirmSensitive: true, since: "2026-01-01T00:00:00Z", until: nil, limit: 10, redactURLs: true)
    #expect(history.map(\.url) == ["https://example.com"])

    #expect(try reader.messageConversations().map(\.chatIdentifier) == ["chat-1"])
    #expect(try reader.recentMessages(confirmSensitive: true, includeBody: false, since: "2026-01-01T00:00:00Z", limit: 10).first?.body == nil)
    #expect(try reader.contacts(search: "Alice", limit: 10, includeNotes: false).map(\.displayName) == ["Alice Example"])
    #expect(try reader.mapFavorites().first?.sensitivity == "high")
    #expect(try reader.newsTopics().map(\.name) == ["Technology"])
}

@Test func readsAppleMessagesChatDatabaseSchema() throws {
    let database = try appleMessagesFixtureDatabase()
    defer { try? FileManager.default.removeItem(at: database.deletingLastPathComponent()) }
    let reader = LocalSQLiteInventoryReader(database: database)

    let conversations = try reader.messageConversations()

    #expect(conversations.map(\.chatIdentifier) == ["iMessage;+;chat@example.com"])
    #expect(conversations.first?.displayName == "Example Chat")
    #expect(conversations.first?.participantCount == 1)
    #expect(conversations.first?.messageCount == 1)

    #expect(throws: LocalInventoryError.sensitiveConfirmationRequired("icloud-cli messages recent")) {
        try reader.recentMessages(confirmSensitive: false, includeBody: false, since: nil, limit: 10)
    }
    let recent = try reader.recentMessages(confirmSensitive: true, includeBody: false, since: nil, limit: 10)
    #expect(recent.map(\.chatIdentifier) == ["iMessage;+;chat@example.com"])
    #expect(recent.first?.sender == "alice@example.com")
    #expect(recent.first?.body == nil)
}

@Test func readsAppleMessagesRecentWithoutChatJoin() throws {
    let root = try temporaryDirectory(named: "apple-messages-direct")
    let database = root.appendingPathComponent("chat.db")
    defer { try? FileManager.default.removeItem(at: root) }
    let sql = """
    CREATE TABLE message (ROWID INTEGER PRIMARY KEY, handle_id INTEGER, date INTEGER, is_from_me INTEGER, text TEXT);
    CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
    CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, guid TEXT, chat_identifier TEXT, display_name TEXT);
    CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
    INSERT INTO handle VALUES (1, 'alice@example.com');
    INSERT INTO message VALUES (1, 1, 771206400000000000, NULL, 'private body');
    """
    try runSQLite(database: database, sql: sql)

    let recent = try LocalSQLiteInventoryReader(database: database).recentMessages(confirmSensitive: true, includeBody: false, since: nil, limit: 10)

    #expect(recent.map(\.chatIdentifier) == ["alice@example.com"])
    #expect(recent.first?.isFromMe == false)
    #expect(recent.first?.body == nil)
}

@Test func readsAppleSafariHistorySchema() throws {
    let root = try temporaryDirectory(named: "apple-safari-history")
    let database = root.appendingPathComponent("History.db")
    defer { try? FileManager.default.removeItem(at: root) }
    let sql = """
    CREATE TABLE history_items (id INTEGER PRIMARY KEY, url TEXT, visit_count INTEGER);
    CREATE TABLE history_visits (id INTEGER PRIMARY KEY, history_item INTEGER, visit_time REAL, title TEXT, load_successful INTEGER);
    INSERT INTO history_items VALUES (1, 'https://example.com/private/path', 3);
    INSERT INTO history_visits VALUES (1, 1, 788961600, 'Example', 1);
    """
    try runSQLite(database: database, sql: sql)

    let history = try LocalSQLiteInventoryReader(database: database).safariHistory(confirmSensitive: true, since: "2026-01-01T00:00:00Z", until: nil, limit: 10, redactURLs: true)

    #expect(history.map(\.url) == ["https://example.com"])
    #expect(history.first?.title == "Example")
    #expect(history.first?.visitedAt == "2026-01-01T12:00:00Z")
    #expect(history.first?.visitCount == 3)
}

@Test func limitsMessageConversations() throws {
    let database = try messageConversationsFixtureDatabase()
    defer { try? FileManager.default.removeItem(at: database.deletingLastPathComponent()) }
    let reader = LocalSQLiteInventoryReader(database: database)

    let conversations = try reader.messageConversations(limit: 1)

    #expect(conversations.map(\.chatIdentifier) == ["chat-new"])
}

@Test func readsAppleAddressBookRecordSchema() throws {
    let database = try appleAddressBookFixtureDatabase()
    defer { try? FileManager.default.removeItem(at: database.deletingLastPathComponent()) }
    let reader = LocalSQLiteInventoryReader(database: database)

    let contacts = try reader.contacts(search: "Alice", limit: 10, includeNotes: false)

    #expect(contacts.map(\.displayName) == ["Alice Example"])
    #expect(contacts.first?.givenName == "Alice")
    #expect(contacts.first?.familyName == "Example")
    #expect(contacts.first?.organizationName == "Example Org")
    #expect(contacts.first?.emails == [ContactEntry.Field(label: "work", value: "alice@example.com")])
    #expect(contacts.first?.phones == [ContactEntry.Field(label: "mobile", value: "+15550101")])
    #expect(contacts.first?.note == nil)

    let withNotes = try reader.contacts(search: nil, limit: 10, includeNotes: true)
    #expect(withNotes.first?.note == "private note")
}

@Test func readsAppleNotesStoreSchema() throws {
    let database = try appleNotesFixtureDatabase()
    defer { try? FileManager.default.removeItem(at: database.deletingLastPathComponent()) }
    let reader = LocalSQLiteInventoryReader(database: database)

    let notes = try reader.notes(folder: "Quick Notes", modifiedSince: "2026-01-01T00:00:00Z", includeBody: false)

    #expect(notes.map(\.title) == ["Plan"])
    #expect(notes.first?.folderName == "Quick Notes")
    #expect(notes.first?.createdAt == "2026-01-01T00:00:00Z")
    #expect(notes.first?.modifiedAt == "2026-01-02T00:00:00Z")
    #expect(notes.first?.isPinned == true)
    #expect(notes.first?.body == nil)

    let withBody = try reader.notes(folder: nil, modifiedSince: nil, includeBody: true)
    #expect(withBody.first?.body == "Sensitive body")
}

@Test func resolvesAddressBookDatabaseInsideSourcesDirectory() throws {
    let root = try temporaryDirectory(named: "addressbook")
    defer { try? FileManager.default.removeItem(at: root) }
    let defaultDatabase = root.appendingPathComponent("AddressBook-v22.abcddb")
    let sourceDatabase = root
        .appendingPathComponent("Sources/source-a", isDirectory: true)
        .appendingPathComponent("AddressBook-v22.abcddb")
    try FileManager.default.createDirectory(at: sourceDatabase.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data().write(to: sourceDatabase)

    let resolved = AddressBookStoreResolver(defaultDatabase: defaultDatabase).database()

    #expect(resolved.standardizedFileURL.path == sourceDatabase.standardizedFileURL.path)
}

@Test func cacheStoreWritesReadsAndReportsStatus() throws {
    let root = try temporaryDirectory(named: "cache")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = CacheWatchStore(outputDirectory: root)

    let status = try store.refresh(commands: ["unknown-command"])

    #expect(status.first?.ok == false)
    #expect(try store.read(command: "unknown-command").ok == false)
    #expect(try store.status().map(\.command) == ["unknown-command"])
}

private func appleMessagesFixtureDatabase() throws -> URL {
    let root = try temporaryDirectory(named: "apple-messages")
    let database = root.appendingPathComponent("chat.db")
    let sql = """
    CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, guid TEXT, chat_identifier TEXT, display_name TEXT);
    CREATE TABLE message (ROWID INTEGER PRIMARY KEY, handle_id INTEGER, date INTEGER, is_from_me INTEGER, text TEXT);
    CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
    CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
    CREATE TABLE chat_handle_join (chat_id INTEGER, handle_id INTEGER);
    INSERT INTO chat VALUES (1, 'chat-guid', 'iMessage;+;chat@example.com', 'Example Chat');
    INSERT INTO handle VALUES (1, 'alice@example.com');
    INSERT INTO message VALUES (1, 1, 771206400000000000, 0, 'private body');
    INSERT INTO chat_message_join VALUES (1, 1);
    INSERT INTO chat_handle_join VALUES (1, 1);
    """
    try runSQLite(database: database, sql: sql)
    return database
}

private func messageConversationsFixtureDatabase() throws -> URL {
    let root = try temporaryDirectory(named: "message-conversations")
    let database = root.appendingPathComponent("inventory.sqlite")
    let sql = """
    CREATE TABLE message_conversations (chatIdentifier TEXT, displayName TEXT, participantCount INTEGER, lastMessageAt TEXT, messageCount INTEGER);
    INSERT INTO message_conversations VALUES ('chat-old', 'Old Chat', 1, '2026-01-01T00:00:00Z', 1);
    INSERT INTO message_conversations VALUES ('chat-new', 'New Chat', 1, '2026-01-02T00:00:00Z', 1);
    """
    try runSQLite(database: database, sql: sql)
    return database
}

private func appleAddressBookFixtureDatabase() throws -> URL {
    let root = try temporaryDirectory(named: "apple-addressbook")
    let database = root.appendingPathComponent("AddressBook-v22.abcddb")
    let sql = """
    CREATE TABLE ZABCDRECORD (
        Z_PK INTEGER PRIMARY KEY,
        ZFIRSTNAME TEXT,
        ZLASTNAME TEXT,
        ZORGANIZATION TEXT,
        ZNOTE TEXT
    );
    CREATE TABLE ZABCDEMAILADDRESS (
        ZOWNER INTEGER,
        ZADDRESS TEXT,
        ZLABEL TEXT
    );
    CREATE TABLE ZABCDPHONENUMBER (
        ZOWNER INTEGER,
        ZFULLNUMBER TEXT,
        ZLABEL TEXT
    );
    INSERT INTO ZABCDRECORD VALUES (1, 'Alice', 'Example', 'Example Org', 'private note');
    INSERT INTO ZABCDRECORD VALUES (2, NULL, NULL, 'Example Org', 'org note');
    INSERT INTO ZABCDEMAILADDRESS VALUES (1, 'alice@example.com', 'work');
    INSERT INTO ZABCDPHONENUMBER VALUES (1, '+15550101', 'mobile');
    """
    try runSQLite(database: database, sql: sql)
    return database
}

private func appleNotesFixtureDatabase() throws -> URL {
    let root = try temporaryDirectory(named: "apple-notes")
    let database = root.appendingPathComponent("NoteStore.sqlite")
    let sql = """
    CREATE TABLE ZICCLOUDSYNCINGOBJECT (
        Z_PK INTEGER PRIMARY KEY,
        ZTITLE1 TEXT,
        ZTITLE2 TEXT,
        ZFOLDER INTEGER,
        ZCREATIONDATE1 REAL,
        ZMODIFICATIONDATE1 REAL,
        ZISPINNED INTEGER,
        ZMARKEDFORDELETION INTEGER
    );
    CREATE TABLE ZICNOTEDATA (ZNOTE INTEGER, ZDATA BLOB);
    INSERT INTO ZICCLOUDSYNCINGOBJECT VALUES (1, NULL, 'Quick Notes', NULL, NULL, NULL, NULL, 0);
    INSERT INTO ZICCLOUDSYNCINGOBJECT VALUES (2, 'Plan', NULL, 1, 788918400, 789004800, 1, 0);
    INSERT INTO ZICCLOUDSYNCINGOBJECT VALUES (3, 'Deleted', NULL, 1, 788918400, 789091200, 0, 1);
    INSERT INTO ZICNOTEDATA VALUES (2, CAST('Sensitive body' AS BLOB));
    """
    try runSQLite(database: database, sql: sql)
    return database
}

private func syntheticInventoryDatabase() throws -> URL {
    let root = try temporaryDirectory(named: "sqlite")
    let database = root.appendingPathComponent("inventory.sqlite")
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
    try runSQLite(database: database, sql: sql)
    return database
}

private func runSQLite(database: URL, sql: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [database.path, sql]
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
}

private func temporaryDirectory(named name: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("icloud-cli-tests")
        .appendingPathComponent(name)
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
