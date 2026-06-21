import Foundation

public enum LocalInventoryError: Error, LocalizedError, Equatable {
    case missingRoot(String)
    case missingStore(String)
    case permissionDenied(String)
    case sensitiveConfirmationRequired(String)
    case unsupportedSchema(store: String, detail: String)
    case sqliteFailure(String)

    public var errorDescription: String? {
        switch self {
        case .missingRoot(let path): return "Inventory root not available: \(path)"
        case .missingStore(let path): return "Inventory store not available: \(path)"
        case .permissionDenied(let path):
            return "Permission denied reading local inventory store: \(path). Grant Full Disk Access to the calling terminal or agent process, then retry."
        case .sensitiveConfirmationRequired(let command):
            return "\(command) reads high-sensitivity local data; rerun with --confirm-sensitive"
        case .unsupportedSchema(let store, let detail):
            return "Inventory store has an unsupported schema: \(store) (\(detail))"
        case .sqliteFailure(let message): return "SQLite query failed: \(message)"
        }
    }
}

public struct PhotoAsset: Codable, Equatable, Sendable {
    public let localIdentifier: String
    public let filename: String
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let mediaType: String
    public let isFavorite: Bool
    public let albumNames: [String]
}

public struct ScreenshotEntry: Codable, Equatable, Sendable {
    public let path: String
    public let filename: String
    public let createdAt: Date?
    public let sizeBytes: Int64
    public let mimeType: String
}

public struct PhotosInventoryReader: Sendable {
    public let screenshotsDirectory: URL
    public let photosLibraryDirectory: URL

    public init(
        screenshotsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/Screenshots"),
        photosLibraryDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/Photos Library.photoslibrary")
    ) {
        self.screenshotsDirectory = screenshotsDirectory
        self.photosLibraryDirectory = photosLibraryDirectory
    }

    public func listScreenshots() throws -> [ScreenshotEntry] {
        guard FileManager.default.fileExists(atPath: screenshotsDirectory.path) else {
            throw LocalInventoryError.missingRoot(screenshotsDirectory.path)
        }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .creationDateKey]
        return try FileManager.default.contentsOfDirectory(at: screenshotsDirectory, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
            .compactMap { url in
                let values = try? url.resourceValues(forKeys: keys)
                guard values?.isDirectory != true, let mimeType = mimeType(for: url), let size = values?.fileSize else { return nil }
                return ScreenshotEntry(path: url.path, filename: url.lastPathComponent, createdAt: values?.creationDate, sizeBytes: Int64(size), mimeType: mimeType)
            }
            .sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
    }

    public func listPhotos(limit: Int = 200) throws -> [PhotoAsset] {
        guard FileManager.default.fileExists(atPath: photosLibraryDirectory.path) else {
            throw LocalInventoryError.missingRoot(photosLibraryDirectory.path)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: photosLibraryDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        let maxAssets = bounded(limit, defaultValue: 200, max: 10_000)
        var assets: [PhotoAsset] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey, .contentModificationDateKey])
            guard values?.isDirectory != true, let mediaType = mediaType(for: url) else { continue }
            assets.append(PhotoAsset(
                localIdentifier: relativePath(url, root: photosLibraryDirectory),
                filename: url.lastPathComponent,
                createdAt: values?.creationDate,
                modifiedAt: values?.contentModificationDate,
                mediaType: mediaType,
                isFavorite: false,
                albumNames: []
            ))
            if assets.count >= maxAssets {
                break
            }
        }
        return assets.sorted { $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
    }

    private func mediaType(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "heic", "gif", "tiff"].contains(ext) { return "photo" }
        if ["mov", "mp4", "m4v"].contains(ext) { return "video" }
        return nil
    }

    private func mimeType(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "gif": return "image/gif"
        case "tiff": return "image/tiff"
        default: return nil
        }
    }
}

public struct NoteEntry: Codable, Equatable, Sendable {
    public let title: String
    public let folderName: String?
    public let createdAt: String?
    public let modifiedAt: String?
    public let isPinned: Bool
    public let body: String?

    enum CodingKeys: String, CodingKey {
        case title, folderName, createdAt, modifiedAt, isPinned, body
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        folderName = try container.decodeIfPresent(String.self, forKey: .folderName)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        modifiedAt = try container.decodeIfPresent(String.self, forKey: .modifiedAt)
        isPinned = try container.decodeFlexibleBool(forKey: .isPinned)
        body = try container.decodeIfPresent(String.self, forKey: .body)
    }
}

public struct ReminderEntry: Codable, Equatable, Sendable {
    public let title: String
    public let listName: String
    public let dueAt: String?
    public let isCompleted: Bool
    public let priority: Int
    public let notes: String?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case title, listName, dueAt, isCompleted, priority, notes, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        listName = try container.decode(String.self, forKey: .listName)
        dueAt = try container.decodeIfPresent(String.self, forKey: .dueAt)
        isCompleted = try container.decodeFlexibleBool(forKey: .isCompleted)
        priority = try container.decode(Int.self, forKey: .priority)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

public struct ReminderListSummary: Codable, Equatable, Sendable {
    public let name: String
    public let itemCount: Int
}

public struct SafariHistoryEntry: Codable, Equatable, Sendable {
    public let url: String
    public let title: String?
    public let visitedAt: String?
    public let visitCount: Int
}

public struct MessageConversation: Codable, Equatable, Sendable {
    public let chatIdentifier: String
    public let displayName: String?
    public let participantCount: Int
    public let lastMessageAt: String?
    public let messageCount: Int
}

public struct MessageRecentEntry: Codable, Equatable, Sendable {
    public let chatIdentifier: String
    public let sender: String?
    public let sentAt: String?
    public let isFromMe: Bool
    public let body: String?

    enum CodingKeys: String, CodingKey {
        case chatIdentifier, sender, sentAt, isFromMe, body
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chatIdentifier = try container.decode(String.self, forKey: .chatIdentifier)
        sender = try container.decodeIfPresent(String.self, forKey: .sender)
        sentAt = try container.decodeIfPresent(String.self, forKey: .sentAt)
        isFromMe = try container.decodeFlexibleBool(forKey: .isFromMe)
        body = try container.decodeIfPresent(String.self, forKey: .body)
    }
}

public struct ContactEntry: Codable, Equatable, Sendable {
    public struct Field: Codable, Equatable, Sendable {
        public let label: String?
        public let value: String
    }

    public let displayName: String
    public let givenName: String?
    public let familyName: String?
    public let organizationName: String?
    public let emails: [Field]
    public let phones: [Field]
    public let note: String?
}

public struct MapPlace: Codable, Equatable, Sendable {
    public let name: String
    public let address: String?
    public let latitude: Double?
    public let longitude: Double?
    public let category: String?
    public let searchedAt: String?
    public let sensitivity: String?
}

public struct NewsHistoryEntry: Codable, Equatable, Sendable {
    public let title: String
    public let source: String?
    public let url: String?
    public let readAt: String?
    public let topic: String?
}

public struct NewsTopicEntry: Codable, Equatable, Sendable {
    public let name: String
    public let type: String
}

public struct LocalSQLiteInventoryReader: Sendable {
    public let database: URL

    public init(database: URL) {
        self.database = database
    }

    public func notes(folder: String?, modifiedSince: String?, includeBody: Bool) throws -> [NoteEntry] {
        if try tableExists("notes") {
            return try syntheticNotes(folder: folder, modifiedSince: modifiedSince, includeBody: includeBody)
        }
        if try tableExists("ZICCLOUDSYNCINGOBJECT") {
            return try appleNotes(folder: folder, modifiedSince: modifiedSince, includeBody: includeBody)
        }
        throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "no such table: notes; missing notes or ZICCLOUDSYNCINGOBJECT tables")
    }

    private func syntheticNotes(folder: String?, modifiedSince: String?, includeBody: Bool) throws -> [NoteEntry] {
        let whereClause = andClause([
            folder.map { "folderName = '\(sqlEscape($0))'" },
            modifiedSince.map { "modifiedAt >= '\(sqlEscape($0))'" },
        ])
        let bodyColumn = includeBody ? "body" : "NULL AS body"
        return try query("SELECT title, folderName, createdAt, modifiedAt, isPinned, \(bodyColumn) FROM notes\(whereClause) ORDER BY modifiedAt DESC, title ASC;")
    }

    private func appleNotes(folder: String?, modifiedSince: String?, includeBody: Bool) throws -> [NoteEntry] {
        let hasNoteData = try tableExists("ZICNOTEDATA")
        let bodyJoin = hasNoteData ? "LEFT JOIN ZICNOTEDATA d ON d.ZNOTE = n.Z_PK" : ""
        let bodyColumn = includeBody && hasNoteData ? "CAST(d.ZDATA AS TEXT)" : "NULL"
        let folderTitleColumn = try columnExists("ZICCLOUDSYNCINGOBJECT", "ZTITLE2") ? "f.ZTITLE2" : "f.ZTITLE1"
        let hasModifiedDate = try columnExists("ZICCLOUDSYNCINGOBJECT", "ZMODIFICATIONDATE1")
        let modifiedExpression = hasModifiedDate ? appleDateExpression("n.ZMODIFICATIONDATE1") : "NULL"
        let createdExpression = try columnExists("ZICCLOUDSYNCINGOBJECT", "ZCREATIONDATE1") ? appleDateExpression("n.ZCREATIONDATE1") : "NULL"
        let pinnedColumn = try columnExists("ZICCLOUDSYNCINGOBJECT", "ZISPINNED") ? "COALESCE(n.ZISPINNED, 0)" : "0"
        let orderClause = hasModifiedDate ? "ORDER BY n.ZMODIFICATIONDATE1 DESC, n.ZTITLE1 ASC" : "ORDER BY n.ZTITLE1 ASC"
        var filters: [String?] = [
            "n.ZTITLE1 IS NOT NULL",
            folder.map { "\(folderTitleColumn) = '\(sqlEscape($0))'" },
        ]
        if try columnExists("ZICCLOUDSYNCINGOBJECT", "ZMARKEDFORDELETION") {
            filters.append("(n.ZMARKEDFORDELETION IS NULL OR n.ZMARKEDFORDELETION = 0)")
        }
        if let modifiedSince {
            filters.append("\(modifiedExpression) >= '\(sqlEscape(modifiedSince))'")
        }
        let whereClause = andClause(filters)

        return try query("""
            SELECT
                n.ZTITLE1 AS title,
                \(folderTitleColumn) AS folderName,
                \(createdExpression) AS createdAt,
                \(modifiedExpression) AS modifiedAt,
                \(pinnedColumn) AS isPinned,
                \(bodyColumn) AS body
            FROM ZICCLOUDSYNCINGOBJECT n
            LEFT JOIN ZICCLOUDSYNCINGOBJECT f ON f.Z_PK = n.ZFOLDER
            \(bodyJoin)
            \(whereClause)
            \(orderClause);
            """)
    }

    public func reminderLists() throws -> [ReminderListSummary] {
        try query("SELECT listName AS name, COUNT(*) AS itemCount FROM reminders GROUP BY listName ORDER BY listName ASC;")
    }

    public func reminders(list: String?, dueBefore: String?, dueAfter: String?, includeCompleted: Bool) throws -> [ReminderEntry] {
        var filters: [String?] = [
            list.map { "listName = '\(sqlEscape($0))'" },
            dueBefore.map { "dueAt IS NOT NULL AND dueAt <= '\(sqlEscape($0))'" },
            dueAfter.map { "dueAt IS NOT NULL AND dueAt >= '\(sqlEscape($0))'" },
        ]
        if !includeCompleted { filters.append("isCompleted = 0") }
        let whereClause = andClause(filters)
        return try query("SELECT title, listName, dueAt, isCompleted, priority, notes, createdAt FROM reminders\(whereClause) ORDER BY dueAt ASC, createdAt ASC;")
    }

    public func safariHistory(confirmSensitive: Bool, since: String?, until: String?, limit: Int, redactURLs: Bool) throws -> [SafariHistoryEntry] {
        guard confirmSensitive else { throw LocalInventoryError.sensitiveConfirmationRequired("icloud-cli safari history") }
        let floor = since ?? ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -86_400))
        let whereClause = andClause([
            "visitedAt >= '\(sqlEscape(floor))'",
            until.map { "visitedAt <= '\(sqlEscape($0))'" },
        ])
        let rows: [SafariHistoryEntry] = try query("SELECT url, title, visitedAt, visitCount FROM safari_history\(whereClause) ORDER BY visitedAt DESC LIMIT \(bounded(limit, defaultValue: 100, max: 1000));")
        if !redactURLs { return rows }
        return rows.map { SafariHistoryEntry(url: redactURL($0.url), title: $0.title, visitedAt: $0.visitedAt, visitCount: $0.visitCount) }
    }

    public func messageConversations(limit: Int = 50) throws -> [MessageConversation] {
        if try tableExists("message_conversations") {
            return try query("SELECT chatIdentifier, displayName, participantCount, lastMessageAt, messageCount FROM message_conversations ORDER BY lastMessageAt DESC LIMIT \(bounded(limit, defaultValue: 50, max: 1000));")
        }
        guard try tableExists("chat"), try tableExists("message"), try tableExists("chat_message_join") else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing message_conversations or chat/message/chat_message_join tables")
        }
        return try query("""
            SELECT
                COALESCE(c.chat_identifier, c.guid) AS chatIdentifier,
                c.display_name AS displayName,
                COUNT(DISTINCT chj.handle_id) AS participantCount,
                CAST(MAX(m.date) AS TEXT) AS lastMessageAt,
                COUNT(m.ROWID) AS messageCount
            FROM chat c
            LEFT JOIN chat_message_join cmj ON cmj.chat_id = c.ROWID
            LEFT JOIN message m ON m.ROWID = cmj.message_id
            LEFT JOIN chat_handle_join chj ON chj.chat_id = c.ROWID
            GROUP BY c.ROWID
            ORDER BY MAX(m.date) DESC
            LIMIT \(bounded(limit, defaultValue: 50, max: 1000));
            """)
    }

    public func recentMessages(confirmSensitive: Bool, includeBody: Bool, since: String?, limit: Int) throws -> [MessageRecentEntry] {
        guard confirmSensitive else { throw LocalInventoryError.sensitiveConfirmationRequired("icloud-cli messages recent") }
        let floor = since ?? ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -86_400))
        let bodyColumn = includeBody ? "body" : "NULL AS body"
        if try tableExists("recent_messages") {
            return try query("SELECT chatIdentifier, sender, sentAt, isFromMe, \(bodyColumn) FROM recent_messages WHERE sentAt >= '\(sqlEscape(floor))' ORDER BY sentAt DESC LIMIT \(bounded(limit, defaultValue: 20, max: 1000));")
        }
        guard try tableExists("message"), try tableExists("chat"), try tableExists("chat_message_join") else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing recent_messages or message/chat/chat_message_join tables")
        }
        let appleBodyColumn = includeBody ? "m.text" : "NULL AS body"
        let appleFloor = since.flatMap { Int64($0) }
        let floorPredicate = appleFloor.map { "WHERE m.date >= \($0)" } ?? ""
        return try query("""
            SELECT
                COALESCE(c.chat_identifier, c.guid) AS chatIdentifier,
                h.id AS sender,
                CAST(m.date AS TEXT) AS sentAt,
                m.is_from_me AS isFromMe,
                \(appleBodyColumn)
            FROM message m
            LEFT JOIN handle h ON h.ROWID = m.handle_id
            LEFT JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
            LEFT JOIN chat c ON c.ROWID = cmj.chat_id
            \(floorPredicate)
            ORDER BY m.date DESC
            LIMIT \(bounded(limit, defaultValue: 20, max: 1000));
            """)
    }

    public func contacts(search: String?, limit: Int, includeNotes: Bool) throws -> [ContactEntry] {
        if try tableExists("contacts") {
            return try syntheticContacts(search: search, limit: limit, includeNotes: includeNotes)
        }
        if try tableExists("ZABCDRECORD") {
            return try appleContacts(search: search, limit: limit, includeNotes: includeNotes)
        }
        throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "no such table: contacts; missing contacts or ZABCDRECORD tables")
    }

    private func syntheticContacts(search: String?, limit: Int, includeNotes: Bool) throws -> [ContactEntry] {
        let noteColumn = includeNotes ? "note" : "NULL AS note"
        let whereClause = search.map {
            let term = sqlEscape($0)
            return " WHERE displayName LIKE '%\(term)%' OR givenName LIKE '%\(term)%' OR familyName LIKE '%\(term)%' OR emails LIKE '%\(term)%' OR phones LIKE '%\(term)%'"
        } ?? ""
        let rows: [RawContactRow] = try query("SELECT displayName, givenName, familyName, organizationName, emails, phones, \(noteColumn) FROM contacts\(whereClause) ORDER BY displayName ASC LIMIT \(bounded(limit, defaultValue: 50, max: 1000));")
        return rows.map { row in
            ContactEntry(
                displayName: row.displayName,
                givenName: row.givenName,
                familyName: row.familyName,
                organizationName: row.organizationName,
                emails: parseContactFields(row.emails),
                phones: parseContactFields(row.phones),
                note: row.note
            )
        }
    }

    private func appleContacts(search: String?, limit: Int, includeNotes: Bool) throws -> [ContactEntry] {
        let givenNameColumn = try contactColumnExpression(["ZFIRSTNAME", "ZGIVENNAME", "ZFIRSTNAME1"], alias: "givenName")
        let familyNameColumn = try contactColumnExpression(["ZLASTNAME", "ZFAMILYNAME", "ZLASTNAME1"], alias: "familyName")
        let organizationColumn = try contactColumnExpression(["ZORGANIZATION", "ZORGANIZATIONNAME", "ZCOMPANY"], alias: "organizationName")
        let noteColumn = includeNotes ? try contactColumnExpression(["ZNOTE", "ZNOTES"], alias: "note") : "NULL AS note"
        let displayNameExpression = try contactDisplayNameExpression()
        let emailsColumn = try contactFieldListSubquery(
            table: "ZABCDEMAILADDRESS",
            ownerCandidates: ["ZOWNER", "Z22_OWNER"],
            valueCandidates: ["ZADDRESS", "ZADDRESSNORMALIZED"],
            alias: "emails"
        )
        let phonesColumn = try contactFieldListSubquery(
            table: "ZABCDPHONENUMBER",
            ownerCandidates: ["ZOWNER", "Z22_OWNER"],
            valueCandidates: ["ZFULLNUMBER", "ZLOCALNUMBER"],
            alias: "phones"
        )
        let searchClause = search.map { term -> String in
            let escaped = sqlEscape(term)
            return """
             WHERE \(displayNameExpression) LIKE '%\(escaped)%'
                OR COALESCE(\(contactColumnReference(["ZFIRSTNAME", "ZGIVENNAME", "ZFIRSTNAME1"])), '') LIKE '%\(escaped)%'
                OR COALESCE(\(contactColumnReference(["ZLASTNAME", "ZFAMILYNAME", "ZLASTNAME1"])), '') LIKE '%\(escaped)%'
                OR COALESCE(\(contactColumnReference(["ZORGANIZATION", "ZORGANIZATIONNAME", "ZCOMPANY"])), '') LIKE '%\(escaped)%'
                OR COALESCE(\(emailsColumn.searchExpression), '') LIKE '%\(escaped)%'
                OR COALESCE(\(phonesColumn.searchExpression), '') LIKE '%\(escaped)%'
            """
        } ?? ""
        let rows: [RawContactRow] = try query("""
            SELECT
                \(displayNameExpression) AS displayName,
                \(givenNameColumn),
                \(familyNameColumn),
                \(organizationColumn),
                \(emailsColumn.selectExpression),
                \(phonesColumn.selectExpression),
                \(noteColumn)
            FROM ZABCDRECORD
            \(searchClause)
            ORDER BY \(displayNameExpression) ASC
            LIMIT \(bounded(limit, defaultValue: 50, max: 1000));
            """)
        return rows.map { row in
            ContactEntry(
                displayName: row.displayName,
                givenName: row.givenName,
                familyName: row.familyName,
                organizationName: row.organizationName,
                emails: parseContactFields(row.emails),
                phones: parseContactFields(row.phones),
                note: row.note
            )
        }
    }

    public func mapFavorites() throws -> [MapPlace] {
        let rows: [RawMapPlace] = try query("SELECT name, address, latitude, longitude, category, NULL AS searchedAt FROM map_favorites ORDER BY name ASC;")
        return rows.map { $0.place() }
    }

    public func mapRecents(limit: Int) throws -> [MapPlace] {
        let rows: [RawMapPlace] = try query("SELECT name, address, latitude, longitude, category, searchedAt FROM map_recents ORDER BY searchedAt DESC LIMIT \(bounded(limit, defaultValue: 20, max: 1000));")
        return rows.map { $0.place() }
    }

    public func newsHistory(since: String?, limit: Int) throws -> [NewsHistoryEntry] {
        let floor = since ?? ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -604_800))
        return try query("SELECT title, source, url, readAt, topic FROM news_history WHERE readAt >= '\(sqlEscape(floor))' ORDER BY readAt DESC LIMIT \(bounded(limit, defaultValue: 50, max: 1000));")
    }

    public func newsTopics() throws -> [NewsTopicEntry] {
        try query("SELECT name, type FROM news_topics ORDER BY name ASC;")
    }

    private func query<T: Decodable>(_ sql: String) throws -> [T] {
        guard FileManager.default.fileExists(atPath: database.path) else { throw LocalInventoryError.missingStore(database.path) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-json", database.path, sql]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            throw sqliteError(from: errorData, store: database.path)
        }
        if data.isEmpty { return [] }
        return try JSONDecoder().decode([T].self, from: data)
    }

    private func tableExists(_ name: String) throws -> Bool {
        let rows: [SQLiteTableRow] = try query("SELECT name FROM sqlite_master WHERE type = 'table' AND name = '\(sqlEscape(name))' LIMIT 1;")
        return !rows.isEmpty
    }

    private func columnExists(_ table: String, _ column: String) throws -> Bool {
        let rows: [SQLitePragmaColumnRow] = try query("PRAGMA table_info('\(sqlEscape(table))');")
        return rows.contains { $0.name == column }
    }

    private func contactColumnReference(_ candidates: [String]) -> String {
        for column in candidates {
            if (try? columnExists("ZABCDRECORD", column)) == true {
                return column
            }
        }
        return "NULL"
    }

    private func contactColumnExpression(_ candidates: [String], alias: String) throws -> String {
        for column in candidates {
            if try columnExists("ZABCDRECORD", column) {
                return "\(column) AS \(alias)"
            }
        }
        return "NULL AS \(alias)"
    }

    private func contactDisplayNameExpression() throws -> String {
        let display = try ["ZDISPLAYNAME", "ZFULLNAME", "ZCOMPOSITEIDENTIFIER"].first { try columnExists("ZABCDRECORD", $0) }
        let given = contactColumnReference(["ZFIRSTNAME", "ZGIVENNAME", "ZFIRSTNAME1"])
        let family = contactColumnReference(["ZLASTNAME", "ZFAMILYNAME", "ZLASTNAME1"])
        let organization = contactColumnReference(["ZORGANIZATION", "ZORGANIZATIONNAME", "ZCOMPANY"])
        let preferred = display.map { "\($0)" } ?? "NULL"
        return "COALESCE(NULLIF(\(preferred), ''), NULLIF(TRIM(COALESCE(\(given), '') || ' ' || COALESCE(\(family), '')), ''), NULLIF(\(organization), ''), 'Contact ' || Z_PK)"
    }

    private func contactFieldListSubquery(table: String, ownerCandidates: [String], valueCandidates: [String], alias: String) throws -> ContactFieldListSQL {
        guard try tableExists(table) else {
            return ContactFieldListSQL(selectExpression: "NULL AS \(alias)", searchExpression: "NULL")
        }
        let ownerColumn = try ownerCandidates.first { try columnExists(table, $0) }
        let valueColumn = try valueCandidates.first { try columnExists(table, $0) }
        guard let ownerColumn, let valueColumn else {
            return ContactFieldListSQL(selectExpression: "NULL AS \(alias)", searchExpression: "NULL")
        }
        let labelExpression = try columnExists(table, "ZLABEL") ? "COALESCE(NULLIF(ZLABEL, ''), 'other')" : "'other'"
        let subquery = """
        (SELECT group_concat(\(labelExpression) || ':' || \(valueColumn), ',')
             FROM \(table)
             WHERE \(table).\(ownerColumn) = ZABCDRECORD.Z_PK
               AND \(valueColumn) IS NOT NULL
               AND \(valueColumn) != '')
        """
        return ContactFieldListSQL(selectExpression: "\(subquery) AS \(alias)", searchExpression: subquery)
    }
}

public struct AddressBookStoreResolver: Sendable {
    public let defaultDatabase: URL

    public init(defaultDatabase: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/AddressBook/AddressBook-v22.abcddb")) {
        self.defaultDatabase = defaultDatabase
    }

    public func database() -> URL {
        if FileManager.default.fileExists(atPath: defaultDatabase.path) {
            return defaultDatabase
        }
        let sourcesDirectory = defaultDatabase
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
        guard let sourceDirectories = try? FileManager.default.contentsOfDirectory(
            at: sourcesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return defaultDatabase
        }
        let candidates = sourceDirectories.compactMap { source -> URL? in
            let values = try? source.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { return nil }
            let database = source.appendingPathComponent(defaultDatabase.lastPathComponent)
            return FileManager.default.fileExists(atPath: database.path) ? database : nil
        }
        return candidates.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }.first ?? defaultDatabase
    }
}

private struct SQLiteTableRow: Decodable {
    let name: String
}

private struct SQLitePragmaColumnRow: Decodable {
    let name: String
}

private struct ContactFieldListSQL {
    let selectExpression: String
    let searchExpression: String
}

func sqliteError(from errorData: Data, store: String) -> LocalInventoryError {
    let message = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    let lowercased = message.lowercased()
    if lowercased.contains("authorization denied") || lowercased.contains("operation not permitted") || lowercased.contains("permission denied") {
        return .permissionDenied(store)
    }
    if lowercased.contains("no such table") || lowercased.contains("no such column") {
        return .unsupportedSchema(store: store, detail: message)
    }
    if lowercased.contains("file is not a database") || lowercased.contains("file is not in a database") {
        return .unsupportedSchema(store: store, detail: "not a SQLite database")
    }
    return .sqliteFailure(message)
}

private struct RawContactRow: Decodable {
    let displayName: String
    let givenName: String?
    let familyName: String?
    let organizationName: String?
    let emails: String?
    let phones: String?
    let note: String?
}

private struct RawMapPlace: Decodable {
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let category: String?
    let searchedAt: String?

    func place() -> MapPlace {
        let sensitivity = ["home", "work"].contains(category?.lowercased() ?? "") ? "high" : nil
        return MapPlace(name: name, address: address, latitude: latitude, longitude: longitude, category: category, searchedAt: searchedAt, sensitivity: sensitivity)
    }
}

private func parseContactFields(_ raw: String?) -> [ContactEntry.Field] {
    guard let raw, !raw.isEmpty else { return [] }
    return raw.split(separator: ",").map { value in
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            return ContactEntry.Field(label: parts[0], value: parts[1])
        }
        return ContactEntry.Field(label: nil, value: parts[0])
    }
}

private func andClause(_ filters: [String?]) -> String {
    let active = filters.compactMap { $0 }.filter { !$0.isEmpty }
    return active.isEmpty ? "" : " WHERE " + active.joined(separator: " AND ")
}

private func bounded(_ value: Int, defaultValue: Int, max: Int) -> Int {
    guard value > 0 else { return defaultValue }
    return Swift.min(value, max)
}

private func appleDateExpression(_ column: String) -> String {
    "CASE WHEN \(column) IS NULL THEN NULL ELSE strftime('%Y-%m-%dT%H:%M:%SZ', \(column) + 978307200, 'unixepoch') END"
}

private func sqlEscape(_ value: String) -> String {
    value.replacingOccurrences(of: "'", with: "''")
}

private func relativePath(_ url: URL, root: URL) -> String {
    let path = url.standardizedFileURL.path
    let rootPath = root.standardizedFileURL.path
    if path == rootPath { return "." }
    if path.hasPrefix(rootPath + "/") { return String(path.dropFirst(rootPath.count + 1)) }
    return path
}

private func redactURL(_ raw: String) -> String {
    guard let components = URLComponents(string: raw), let scheme = components.scheme, let host = components.host else {
        return raw
    }
    return "\(scheme)://\(host)"
}

private extension KeyedDecodingContainer {
    func decodeFlexibleBool(forKey key: Key) throws -> Bool {
        if let value = try? decode(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? decode(String.self, forKey: key) {
            return ["1", "true", "yes"].contains(value.lowercased())
        }
        return false
    }
}
