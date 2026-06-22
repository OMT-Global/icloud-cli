import Foundation

public enum MetadataValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        case .null: return nil
        }
    }

    public var intValue: Int? {
        switch self {
        case .int(let value): return value
        case .string(let value): return Int(value)
        default: return nil
        }
    }
}

public struct MetadataRow: Codable, Equatable, Sendable {
    public let kind: String
    public let fields: [String: MetadataValue]

    public init(kind: String, fields: [String: MetadataValue]) {
        self.kind = kind
        self.fields = fields
    }

    public func string(_ key: String) -> String? {
        fields[key]?.stringValue
    }

    public func int(_ key: String) -> Int? {
        fields[key]?.intValue
    }
}

public struct LocalMetadataStoreReader: Sendable {
    public let database: URL

    public init(database: URL) {
        self.database = database
    }

    public func rows(for command: MetadataCommand, options: MetadataOptions = MetadataOptions()) throws -> [MetadataRow] {
        try requireConfirmationIfNeeded(command: command, options: options)
        if command == .safariCloudTabsList {
            return try cloudTabRows(options: options)
        }
        if command == .calendarAccounts || command == .calendarList || command == .calendarEvents {
            return try calendarRows(for: command, options: options)
        }
        if command == .booksCollections || command == .booksList {
            return try booksRows(for: command, options: options)
        }
        if command == .mailAccounts || command == .mailMailboxes || command == .mailRecent {
            return try mailRows(for: command, options: options)
        }
        if command == .notesAccounts || command == .notesFolders || command == .notesTags || command == .notesShared {
            return try notesRows(for: command, options: options)
        }
        if command == .photosSharedAlbums || command == .photosSharedLibrary {
            return try photosRows(for: command, options: options)
        }
        if command == .remindersAssigned || command == .remindersFlagged || command == .remindersScheduled || command == .remindersToday {
            return try reminderRows(for: command, options: options)
        }
        if command == .musicStatus || command == .musicPlaylists || command == .musicTracks {
            try validateSQLiteStore(featureName: "Music library")
        }
        guard let tableName = command.tableName else {
            throw LocalInventoryError.sqliteFailure("No metadata table configured for \(command.displayName)")
        }
        var rows = try query("SELECT * FROM \(tableName)\(whereClause(for: command, options: options))\(orderClause(for: command)) LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));")
            .map { MetadataRow(kind: command.displayName, fields: $0) }
        rows = rows.map { redact(row: $0, command: command, options: options) }
        return rows
    }

    private func cloudTabRows(options: MetadataOptions) throws -> [MetadataRow] {
        guard try tableExists("cloud_tabs"), try tableExists("cloud_tab_devices") else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing Safari cloud_tabs or cloud_tab_devices tables")
        }
        var filters: [String] = []
        if let device = options.device {
            filters.append("d.device_name = '\(sqlEscape(device))'")
        }
        let urlExpression = options.includeURLs ? "CAST(t.url AS TEXT)" : "NULL"
        let whereSQL = filters.isEmpty ? "" : " WHERE " + filters.joined(separator: " AND ")
        let sql = """
            SELECT
                CAST(d.device_name AS TEXT) AS deviceName,
                CAST(t.title AS TEXT) AS title,
                \(urlExpression) AS url,
                CAST(d.last_modified AS TEXT) AS lastSyncedAt,
                CASE WHEN typeof(t.position) = 'integer' THEN t.position ELSE 0 END AS position,
                COALESCE(t.is_pinned, 0) AS isPinned,
                COALESCE(t.is_showing_reader, 0) AS isShowingReader,
                CAST(t.scene_id AS TEXT) AS sceneID
            FROM cloud_tabs t
            LEFT JOIN cloud_tab_devices d ON d.device_uuid = t.device_uuid
            \(whereSQL)
            ORDER BY d.device_name ASC, position ASC
            LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
            """
        return try query(sql)
            .map { MetadataRow(kind: MetadataCommand.safariCloudTabsList.displayName, fields: $0) }
            .map { redact(row: $0, command: .safariCloudTabsList, options: options) }
    }

    private func calendarRows(for command: MetadataCommand, options: MetadataOptions) throws -> [MetadataRow] {
        if try tableExists(command.tableName ?? "") {
            guard let tableName = command.tableName else { return [] }
            return try query("SELECT * FROM \(tableName)\(whereClause(for: command, options: options))\(orderClause(for: command)) LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));")
                .map { MetadataRow(kind: command.displayName, fields: $0) }
                .map { redact(row: $0, command: command, options: options) }
        }
        guard try tableExists("Calendar"), try tableExists("Store") else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing calendar metadata tables or Apple Calendar tables")
        }
        switch command {
        case .calendarAccounts:
            return try query("""
                SELECT
                    COALESCE(NULLIF(s.name, ''), 'Calendar Account ' || s.ROWID) AS name,
                    CASE s.type
                        WHEN 1 THEN 'Local'
                        WHEN 2 THEN 'Exchange'
                        WHEN 3 THEN 'CalDAV'
                        WHEN 4 THEN 'Subscribed'
                        ELSE CAST(s.type AS TEXT)
                    END AS type,
                    COUNT(c.ROWID) AS calendarCount
                FROM Store s
                LEFT JOIN Calendar c ON c.store_id = s.ROWID
                WHERE COALESCE(s.disabled, 0) = 0
                GROUP BY s.ROWID
                ORDER BY name ASC
                LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
                """).map { MetadataRow(kind: command.displayName, fields: $0) }
        case .calendarList:
            return try query("""
                SELECT
                    COALESCE(NULLIF(c.title, ''), 'Calendar ' || c.ROWID) AS title,
                    COALESCE(NULLIF(s.name, ''), 'Calendar Account ' || s.ROWID) AS account,
                    c.color AS color,
                    CASE c.type
                        WHEN 'com.apple.ical.sources.local' THEN 'Local'
                        WHEN 'com.apple.ical.sources.caldav' THEN 'CalDAV'
                        ELSE c.type
                    END AS source,
                    CASE WHEN c.ROWID = s.delegated_account_default_calendar_for_new_events_id THEN 1 ELSE 0 END AS isDefault
                FROM Calendar c
                LEFT JOIN Store s ON s.ROWID = c.store_id
                WHERE COALESCE(c.flags, 0) >= 0
                ORDER BY account ASC, title ASC
                LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
                """).map { MetadataRow(kind: command.displayName, fields: $0) }
        case .calendarEvents:
            guard try tableExists("CalendarItem") else {
                throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing Apple Calendar CalendarItem table")
            }
            let startsAt = appleDateExpression("i.start_date")
            let endsAt = appleDateExpression("i.end_date")
            let since = options.since ?? ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -86_400))
            let filters = andClause([
                "COALESCE(i.hidden, 0) = 0",
                "i.start_date IS NOT NULL",
                "\(startsAt) >= '\(sqlEscape(since))'",
                options.until.map { "\(startsAt) <= '\(sqlEscape($0))'" },
                options.calendar.map { "c.title = '\(sqlEscape($0))'" },
            ])
            let participantSubquery = try tableExists("Participant") ? """
                (SELECT group_concat(COALESCE(NULLIF(p.email, ''), NULLIF(p.phone_number, ''), 'participant'), ',')
                 FROM Participant p
                 WHERE p.owner_id = i.ROWID)
                """ : "NULL"
            return try query("""
                SELECT
                    COALESCE(NULLIF(i.summary, ''), 'Event ' || i.ROWID) AS title,
                    COALESCE(NULLIF(c.title, ''), 'Calendar ' || c.ROWID) AS calendar,
                    \(startsAt) AS startsAt,
                    \(endsAt) AS endsAt,
                    COALESCE(i.all_day, 0) AS isAllDay,
                    \(participantSubquery) AS attendees,
                    i.description AS notes
                FROM CalendarItem i
                LEFT JOIN Calendar c ON c.ROWID = i.calendar_id
                \(filters)
                ORDER BY i.start_date ASC
                LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
                """)
                .map { MetadataRow(kind: command.displayName, fields: $0) }
                .map { redact(row: $0, command: command, options: options) }
        default:
            return []
        }
    }

    private func booksRows(for command: MetadataCommand, options: MetadataOptions) throws -> [MetadataRow] {
        if try tableExists(command.tableName ?? "") {
            guard let tableName = command.tableName else { return [] }
            return try query("SELECT * FROM \(tableName)\(whereClause(for: command, options: options))\(orderClause(for: command)) LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));")
                .map { MetadataRow(kind: command.displayName, fields: $0) }
                .map { redact(row: $0, command: command, options: options) }
        }
        guard try tableExists("ZBKLIBRARYASSET") else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing books or ZBKLIBRARYASSET tables")
        }
        switch command {
        case .booksCollections:
            guard try tableExists("ZBKCOLLECTION") else { return [] }
            return try query("""
                SELECT
                    COALESCE(NULLIF(c.ZTITLE, ''), c.ZCOLLECTIONID, 'Collection ' || c.Z_PK) AS name,
                    COUNT(m.Z_PK) AS bookCount
                FROM ZBKCOLLECTION c
                LEFT JOIN ZBKCOLLECTIONMEMBER m ON m.ZCOLLECTION = c.Z_PK
                WHERE COALESCE(c.ZDELETEDFLAG, 0) = 0
                GROUP BY c.Z_PK
                ORDER BY name ASC
                LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
                """).map { MetadataRow(kind: command.displayName, fields: $0) }
        case .booksList:
            let hasCollections = try tableExists("ZBKCOLLECTION")
            let hasCollectionMembers = try tableExists("ZBKCOLLECTIONMEMBER")
            let hasCollectionJoin = hasCollections && hasCollectionMembers
            let collectionJoin = hasCollectionJoin ? """
                LEFT JOIN ZBKCOLLECTIONMEMBER m ON m.ZASSET = a.Z_PK
                LEFT JOIN ZBKCOLLECTION c ON c.Z_PK = m.ZCOLLECTION
                """ : ""
            let collectionColumn = collectionJoin.isEmpty ? "NULL" : "c.ZTITLE"
            let collectionFilter = options.collection.map { " AND \(collectionColumn) = '\(sqlEscape($0))'" } ?? ""
            let rows = try query("""
                SELECT
                    COALESCE(NULLIF(a.ZTITLE, ''), a.ZASSETID, 'Book ' || a.Z_PK) AS title,
                    a.ZAUTHOR AS author,
                    a.ZKIND AS format,
                    \(collectionColumn) AS collection,
                    CAST(a.ZREADINGPROGRESS * 100 AS INTEGER) AS progressPercent,
                    NULL AS highlightCount
                FROM ZBKLIBRARYASSET a
                \(collectionJoin)
                WHERE COALESCE(a.ZISHIDDEN, 0) = 0\(collectionFilter)
                ORDER BY title ASC
                LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
                """).map { MetadataRow(kind: command.displayName, fields: $0) }
            return rows.map { redact(row: $0, command: command, options: options) }
        default:
            return []
        }
    }

    private func mailRows(for command: MetadataCommand, options: MetadataOptions) throws -> [MetadataRow] {
        if try tableExists(command.tableName ?? "") {
            guard let tableName = command.tableName else { return [] }
            return try query("SELECT * FROM \(tableName)\(whereClause(for: command, options: options))\(orderClause(for: command)) LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));")
                .map { MetadataRow(kind: command.displayName, fields: $0) }
        }
        let hasAppleMailboxes = try tableExists("mailboxes")
        let hasAppleMessages = try tableExists("messages")
        guard hasAppleMailboxes || hasAppleMessages else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing mail metadata tables or Apple Mail Envelope Index tables")
        }
        switch command {
        case .mailAccounts:
            return try appleMailAccounts(options: options)
        case .mailMailboxes:
            return try appleMailMailboxes(options: options)
        case .mailRecent:
            return try appleMailRecent(options: options)
        default:
            return []
        }
    }

    private func notesRows(for command: MetadataCommand, options: MetadataOptions) throws -> [MetadataRow] {
        if try tableExists(command.tableName ?? "") {
            guard let tableName = command.tableName else { return [] }
            return try query("SELECT * FROM \(tableName)\(whereClause(for: command, options: options))\(orderClause(for: command)) LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));")
                .map { MetadataRow(kind: command.displayName, fields: $0) }
        }
        guard try tableExists("ZICCLOUDSYNCINGOBJECT") else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing notes metadata tables or ZICCLOUDSYNCINGOBJECT table")
        }
        switch command {
        case .notesAccounts:
            let columns = try columns(in: "ZICCLOUDSYNCINGOBJECT")
            let accountExpression = columns.contains("ZACCOUNTNAMEFORACCOUNTLISTSORTING") ? "COALESCE(NULLIF(ZACCOUNTNAMEFORACCOUNTLISTSORTING, ''), 'Local Notes')" : "'Local Notes'"
            let folderPredicate = columns.contains("ZNAME") ? "(ZTITLE2 IS NOT NULL OR ZNAME IS NOT NULL)" : "ZTITLE2 IS NOT NULL"
            return try query("""
                SELECT
                    \(accountExpression) AS name,
                    COUNT(CASE WHEN ZTITLE1 IS NOT NULL THEN 1 END) AS noteCount,
                    COUNT(CASE WHEN \(folderPredicate) THEN 1 END) AS folderCount
                FROM ZICCLOUDSYNCINGOBJECT
                WHERE COALESCE(ZMARKEDFORDELETION, 0) = 0
                GROUP BY name
                ORDER BY name ASC
                LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
                """).map { MetadataRow(kind: command.displayName, fields: $0) }
        case .notesFolders:
            let columns = try columns(in: "ZICCLOUDSYNCINGOBJECT")
            let nameCandidates = [
                columns.contains("ZTITLE2") ? "NULLIF(f.ZTITLE2, '')" : nil,
                columns.contains("ZNAME") ? "NULLIF(f.ZNAME, '')" : nil,
                "'Folder ' || f.Z_PK",
            ].compactMap { $0 }
            let nameExpression = "COALESCE(\(nameCandidates.joined(separator: ", ")))"
            let accountExpression = columns.contains("ZACCOUNTNAMEFORACCOUNTLISTSORTING") ? "f.ZACCOUNTNAMEFORACCOUNTLISTSORTING" : "NULL"
            let accountFilter = options.account.map { " AND \(accountExpression) = '\(sqlEscape($0))'" } ?? ""
            let sharedExpression = columns.contains("ZISSHAREDIRTY") ? "COALESCE(f.ZISSHAREDIRTY, 0)" : "0"
            let folderPredicate = columns.contains("ZNAME") ? "(f.ZTITLE2 IS NOT NULL OR f.ZNAME IS NOT NULL)" : "f.ZTITLE2 IS NOT NULL"
            return try query("""
                SELECT
                    \(nameExpression) AS name,
                    \(accountExpression) AS account,
                    COUNT(n.Z_PK) AS noteCount,
                    \(sharedExpression) AS shared
                FROM ZICCLOUDSYNCINGOBJECT f
                LEFT JOIN ZICCLOUDSYNCINGOBJECT n ON n.ZFOLDER = f.Z_PK AND n.ZTITLE1 IS NOT NULL AND COALESCE(n.ZMARKEDFORDELETION, 0) = 0
                WHERE \(folderPredicate)\(accountFilter)
                  AND COALESCE(f.ZMARKEDFORDELETION, 0) = 0
                GROUP BY f.Z_PK
                ORDER BY name ASC
                LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
                """).map { MetadataRow(kind: command.displayName, fields: $0) }
        case .notesTags:
            return []
        case .notesShared:
            guard try tableExists("ZICINVITATION") else { return [] }
            return try query("""
                SELECT
                    COALESCE(NULLIF(ZTITLE, ''), 'Shared Note') AS title,
                    COALESCE(ZNOTECOUNT, 0) AS noteCount
                FROM ZICINVITATION
                ORDER BY title ASC
                LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
                """).map { MetadataRow(kind: command.displayName, fields: $0) }
        default:
            return []
        }
    }

    private func photosRows(for command: MetadataCommand, options: MetadataOptions) throws -> [MetadataRow] {
        if try tableExists(command.tableName ?? "") {
            guard let tableName = command.tableName else { return [] }
            return try query("SELECT * FROM \(tableName)\(whereClause(for: command, options: options))\(orderClause(for: command)) LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));")
                .map { MetadataRow(kind: command.displayName, fields: $0) }
        }
        switch command {
        case .photosSharedAlbums:
            guard try tableExists("ZGENERICALBUM") else {
                throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing photos_shared_albums or ZGENERICALBUM tables")
            }
            let columns = try columns(in: "ZGENERICALBUM")
            let titleExpression = coalesceRawExpression(candidates: ["ZTITLE", "ZCLOUDGUID", "ZUUID"], columns: columns, fallback: "'Shared Album ' || Z_PK")
            let assetCountExpression = coalesceRawExpression(candidates: ["ZCACHEDCOUNT", "ZCACHEDPHOTOSCOUNT"], columns: columns, fallback: "0")
            let ownerExpression = columns.contains("ZCLOUDOWNERFULLNAME") ? "ZCLOUDOWNERFULLNAME" : "NULL"
            let collaborationExpression = columns.contains("ZCLOUDMULTIPLECONTRIBUTORSENABLED") ? "COALESCE(ZCLOUDMULTIPLECONTRIBUTORSENABLED, 0)" : "0"
            let updatedExpression = columns.contains("ZCLOUDLASTCONTRIBUTIONDATE") ? "CASE WHEN ZCLOUDLASTCONTRIBUTIONDATE IS NULL THEN NULL ELSE strftime('%Y-%m-%dT%H:%M:%SZ', ZCLOUDLASTCONTRIBUTIONDATE + 978307200, 'unixepoch') END" : "NULL"
            let cloudPredicate = columns.contains("ZCLOUDGUID") ? "ZCLOUDGUID IS NOT NULL" : "1 = 1"
            let trashedPredicate = columns.contains("ZTRASHEDSTATE") ? "COALESCE(ZTRASHEDSTATE, 0) = 0" : "1 = 1"
            return try query("""
                SELECT
                    \(titleExpression) AS title,
                    \(ownerExpression) AS owner,
                    \(collaborationExpression) AS collaborationEnabled,
                    \(assetCountExpression) AS assetCount,
                    \(updatedExpression) AS updatedAt
                FROM ZGENERICALBUM
                WHERE \(cloudPredicate)
                  AND \(trashedPredicate)
                ORDER BY title ASC
                LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
                """).map { MetadataRow(kind: command.displayName, fields: $0) }
        case .photosSharedLibrary:
            guard try tableExists("ZSHARE") else {
                throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing photos_shared_library or ZSHARE tables")
            }
            let columns = try columns(in: "ZSHARE")
            let titleExpression = coalesceRawExpression(candidates: ["ZTITLE", "ZSCOPEIDENTIFIER", "ZUUID"], columns: columns, fallback: "'Shared Library'")
            let assetCountExpression = coalesceRawExpression(candidates: ["ZASSETCOUNT", "ZCLOUDITEMCOUNT", "ZPHOTOSCOUNT"], columns: columns, fallback: "0")
            let statusExpression = columns.contains("ZSTATUS") ? "ZSTATUS" : "NULL"
            let scopeExpression = columns.contains("ZSCOPETYPE") ? "ZSCOPETYPE" : "NULL"
            let trashedPredicate = columns.contains("ZTRASHEDSTATE") ? "COALESCE(ZTRASHEDSTATE, 0) = 0" : "1 = 1"
            return try query("""
                SELECT
                    \(titleExpression) AS title,
                    \(statusExpression) AS status,
                    \(scopeExpression) AS scopeType,
                    \(assetCountExpression) AS assetCount,
                    COALESCE((
                        SELECT COUNT(*)
                        FROM ZSHAREPARTICIPANT p
                        WHERE p.ZSHARE = ZSHARE.Z_PK OR p.Z66_SHARE = ZSHARE.Z_PK
                    ), 0) AS participantCount
                FROM ZSHARE
                WHERE \(trashedPredicate)
                ORDER BY title ASC
                LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
                """).map { MetadataRow(kind: command.displayName, fields: $0) }
        default:
            return []
        }
    }

    private func reminderRows(for command: MetadataCommand, options: MetadataOptions) throws -> [MetadataRow] {
        if try tableExists(command.tableName ?? "") {
            guard let tableName = command.tableName else { return [] }
            return try query("SELECT * FROM \(tableName)\(whereClause(for: command, options: options))\(orderClause(for: command)) LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));")
                .map { MetadataRow(kind: command.displayName, fields: $0) }
                .map { redact(row: $0, command: command, options: options) }
        }
        guard try tableExists("ZREMCDREMINDER"), try tableExists("ZREMCDBASELIST") else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing reminders metadata table or Apple Reminders CoreData tables")
        }
        let dueExpression = appleDateExpression("r.ZDUEDATE")
        let createdExpression = appleDateExpression("r.ZCREATIONDATE")
        let assignmentExpression = try tableExists("ZREMCDOBJECT") ? """
            EXISTS (
                SELECT 1
                FROM ZREMCDOBJECT o
                WHERE (o.ZREMINDER = r.Z_PK OR o.ZREMINDER1 = r.Z_PK OR o.ZREMINDER2 = r.Z_PK OR o.Z_FOK_REMINDER = r.Z_PK)
                  AND o.ZASSIGNEE IS NOT NULL
            )
            """ : "0"
        var filters: [String?] = ["COALESCE(r.ZMARKEDFORDELETION, 0) = 0"]
        switch command {
        case .remindersFlagged:
            filters.append("COALESCE(r.ZFLAGGED, 0) = 1")
            filters.append("COALESCE(r.ZCOMPLETED, 0) = 0")
        case .remindersToday:
            filters.append("\(dueExpression) IS NOT NULL")
            filters.append("\(dueExpression) <= strftime('%Y-%m-%dT%H:%M:%SZ', 'now', '+1 day')")
            filters.append("COALESCE(r.ZCOMPLETED, 0) = 0")
        case .remindersScheduled:
            filters.append("\(dueExpression) IS NOT NULL")
            filters.append(options.since.map { "\(dueExpression) >= '\(sqlEscape($0))'" })
            filters.append(options.until.map { "\(dueExpression) <= '\(sqlEscape($0))'" })
        case .remindersAssigned:
            filters.append("\(assignmentExpression)")
            filters.append("COALESCE(r.ZCOMPLETED, 0) = 0")
        default:
            break
        }
        return try query("""
            SELECT
                COALESCE(NULLIF(r.ZTITLE, ''), 'Reminder ' || r.Z_PK) AS title,
                COALESCE(NULLIF(l.ZNAME, ''), 'List ' || l.Z_PK) AS listName,
                \(dueExpression) AS dueAt,
                COALESCE(r.ZCOMPLETED, 0) AS isCompleted,
                COALESCE(r.ZPRIORITY, 0) AS priority,
                r.ZNOTES AS notes,
                \(createdExpression) AS createdAt,
                COALESCE(r.ZFLAGGED, 0) AS isFlagged,
                CASE WHEN \(assignmentExpression) THEN 1 ELSE 0 END AS assignedToMe
            FROM ZREMCDREMINDER r
            LEFT JOIN ZREMCDBASELIST l ON l.Z_PK = r.ZLIST
            \(andClause(filters))
            ORDER BY dueAt ASC, createdAt ASC
            LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
            """)
            .map { MetadataRow(kind: command.displayName, fields: $0) }
            .map { redact(row: $0, command: command, options: options) }
    }

    private func appleMailAccounts(options: MetadataOptions) throws -> [MetadataRow] {
        guard try tableExists("mailboxes") else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing Apple Mail mailboxes table")
        }
        let mailboxColumns = try columns(in: "mailboxes")
        let displayName = coalesceExpression(
            candidates: ["account_identifier", "account_url", "url", "name"],
            columns: mailboxColumns,
            alias: "displayName",
            fallback: "'Local Mail'"
        )
        let accountLocator = coalesceRawExpression(candidates: ["account_url", "url"], columns: mailboxColumns, fallback: "''")
        let sql = """
            SELECT
                \(displayName),
                CASE
                    WHEN \(accountLocator) LIKE '%icloud%' THEN 'iCloud'
                    WHEN \(accountLocator) LIKE 'imap://%' THEN 'IMAP'
                    WHEN \(accountLocator) LIKE 'pop://%' THEN 'POP'
                    ELSE NULL
                END AS type,
                COUNT(*) AS mailboxCount
            FROM mailboxes
            GROUP BY displayName, type
            ORDER BY displayName ASC
            LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
            """
        return try query(sql).map { MetadataRow(kind: MetadataCommand.mailAccounts.displayName, fields: $0) }
    }

    private func appleMailMailboxes(options: MetadataOptions) throws -> [MetadataRow] {
        guard try tableExists("mailboxes") else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing Apple Mail mailboxes table")
        }
        let mailboxColumns = try columns(in: "mailboxes")
        let messageColumns = try tableExists("messages") ? columns(in: "messages") : []
        let account = coalesceRawExpression(candidates: ["account_identifier", "account_url", "url"], columns: mailboxColumns, tableAlias: "m", fallback: "'Local Mail'")
        let mailbox = coalesceRawExpression(candidates: ["name", "url"], columns: mailboxColumns, tableAlias: "m", fallback: "CAST(m.ROWID AS TEXT)")
        let hasMessages = !messageColumns.isEmpty && messageColumns.contains("mailbox")
        let total = coalesceRawExpression(candidates: ["total_count", "messages_count"], columns: mailboxColumns, tableAlias: "m", fallback: hasMessages ? "COUNT(msg.ROWID)" : "0")
        let unread = coalesceRawExpression(candidates: ["unread_count"], columns: mailboxColumns, tableAlias: "m", fallback: hasMessages && messageColumns.contains("read") ? "SUM(CASE WHEN COALESCE(msg.read, 0) = 0 THEN 1 ELSE 0 END)" : "0")
        let joinMessages = hasMessages ? "LEFT JOIN messages msg ON msg.mailbox = m.ROWID" : ""
        let accountFilter = options.account.map { " AND \(account) = '\(sqlEscape($0))'" } ?? ""
        let sql = """
            SELECT
                \(account) AS account,
                \(mailbox) AS mailbox,
                \(total) AS totalCount,
                \(unread) AS unreadCount
            FROM mailboxes m
            \(joinMessages)
            WHERE 1 = 1\(accountFilter)
            GROUP BY m.ROWID
            ORDER BY account ASC, mailbox ASC
            LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
            """
        return try query(sql).map { MetadataRow(kind: MetadataCommand.mailMailboxes.displayName, fields: $0) }
    }

    private func appleMailRecent(options: MetadataOptions) throws -> [MetadataRow] {
        guard try tableExists("messages"), try tableExists("mailboxes") else {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "missing Apple Mail messages or mailboxes table")
        }
        let mailboxColumns = try columns(in: "mailboxes")
        let messageColumns = try columns(in: "messages")
        let account = coalesceRawExpression(candidates: ["account_identifier", "account_url", "url"], columns: mailboxColumns, tableAlias: "mb", fallback: "'Local Mail'")
        let mailboxFallback = messageColumns.contains("mailbox") ? "CAST(msg.mailbox AS TEXT)" : "NULL"
        let mailbox = coalesceRawExpression(candidates: ["name", "url"], columns: mailboxColumns, tableAlias: "mb", fallback: mailboxFallback)
        let accountFilter = options.account.map { " AND \(account) = '\(sqlEscape($0))'" } ?? ""
        let mailboxFilter = options.mailbox.map { " AND \(mailbox) = '\(sqlEscape($0))'" } ?? ""
        let hasAddresses = try tableExists("addresses") && messageColumns.contains("sender")
        let addressColumns = hasAddresses ? try columns(in: "addresses") : []
        let senderExpression = hasAddresses ? coalesceRawExpression(candidates: ["address", "comment"], columns: addressColumns, tableAlias: "a", fallback: "CAST(msg.sender AS TEXT)") : (messageColumns.contains("sender") ? "CAST(msg.sender AS TEXT)" : "NULL")
        let senderJoin = hasAddresses ? "LEFT JOIN addresses a ON a.ROWID = msg.sender" : ""
        let hasSubjects = try tableExists("subjects") && messageColumns.contains("subject")
        let subjectColumns = hasSubjects ? try columns(in: "subjects") : []
        let subjectExpression = hasSubjects ? coalesceRawExpression(candidates: ["subject"], columns: subjectColumns, tableAlias: "s", fallback: "CAST(msg.subject AS TEXT)") : (messageColumns.contains("subject") ? "CAST(msg.subject AS TEXT)" : "NULL")
        let subjectJoin = hasSubjects ? "LEFT JOIN subjects s ON s.ROWID = msg.subject" : ""
        let dateExpression = coalesceRawExpression(candidates: ["date_sent", "date_received", "date_last_viewed"], columns: messageColumns, tableAlias: "msg", fallback: "0")
        let mailboxJoin = messageColumns.contains("mailbox") ? "LEFT JOIN mailboxes mb ON mb.ROWID = msg.mailbox" : "LEFT JOIN mailboxes mb ON 0"
        let sql = """
            SELECT
                \(senderExpression) AS sender,
                \(subjectExpression) AS subject,
                datetime(\(dateExpression), 'unixepoch') AS sentAt,
                \(mailbox) AS mailbox
            FROM messages msg
            \(mailboxJoin)
            \(senderJoin)
            \(subjectJoin)
            WHERE 1 = 1\(accountFilter)\(mailboxFilter)
            ORDER BY \(dateExpression) DESC
            LIMIT \(bounded(options.limit, defaultValue: 50, max: 1000));
            """
        return try query(sql).map { MetadataRow(kind: MetadataCommand.mailRecent.displayName, fields: $0) }
    }

    public static func defaultStore(for command: MetadataCommand) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch command {
        case .calendarAccounts, .calendarEvents, .calendarList:
            return firstExisting(
                in: home.appendingPathComponent("Library/Group Containers/group.com.apple.calendar"),
                matching: { $0.lastPathComponent == "Calendar.sqlitedb" }
            ) ?? home.appendingPathComponent("Library/Calendars/Calendar Cache")
        case .findMyDevices, .findMyPeople:
            return home.appendingPathComponent("Library/Caches/com.apple.findmy.fmipcore/findmy.sqlite")
        case .mailAccounts, .mailMailboxes, .mailRecent:
            return home.appendingPathComponent("Library/Mail/V10/MailData/Envelope Index")
        case .booksCollections, .booksList:
            return firstExisting(
                in: home.appendingPathComponent("Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary"),
                matching: { $0.lastPathComponent.hasPrefix("BKLibrary-") && $0.pathExtension == "sqlite" }
            ) ?? home.appendingPathComponent("Library/Containers/com.apple.iBooksX/Data/Documents/BKLibrary/BKLibrary.sqlite")
        case .healthSummary:
            return home.appendingPathComponent("Library/Health/healthdb_secure.sqlite")
        case .photosSharedAlbums, .photosSharedLibrary:
            return firstExisting(
                in: home.appendingPathComponent("Pictures/Photos Library.photoslibrary/database"),
                matching: { $0.lastPathComponent == "Photos.sqlite" }
            ) ?? home.appendingPathComponent("Pictures/Photos Library.photoslibrary/database/Photos.sqlite")
        case .safariCloudTabsList:
            return home.appendingPathComponent("Library/Safari/CloudTabs.db")
        case .safariExtensionsList, .safariProfilesList:
            return home.appendingPathComponent("Library/Safari/SafariMetadata.sqlite")
        case .musicPlaylists, .musicStatus, .musicTracks:
            return home.appendingPathComponent("Music/Music/Music Library.musiclibrary/Library.musicdb")
        case .weatherFavorites:
            return home.appendingPathComponent("Library/Containers/com.apple.weather/Data/Library/Application Support/weather.sqlite")
        case .stocksGroups, .stocksWatchlist:
            return home.appendingPathComponent("Library/Containers/com.apple.stocks/Data/Library/Application Support/stocks.sqlite")
        case .freeformList:
            return home.appendingPathComponent("Library/Containers/com.apple.freeform/Data/Library/Application Support/freeform.sqlite")
        case .homeAccessories, .homeHomes, .homeRooms, .homeScenes:
            return home.appendingPathComponent("Library/Application Support/com.apple.homed/Home.sqlite")
        case .voiceMemosList:
            return home.appendingPathComponent("Library/Application Support/com.apple.voicememos/Recordings.db")
        case .notesAccounts, .notesFolders, .notesShared, .notesTags:
            return home.appendingPathComponent("Library/Group Containers/group.com.apple.notes/NoteStore.sqlite")
        case .remindersAssigned, .remindersFlagged, .remindersScheduled, .remindersToday:
            return AppleRemindersStoreResolver().database() ?? home.appendingPathComponent("Library/Reminders/reminders.sqlite")
        default:
            return home.appendingPathComponent("Library/Preferences/MobileMeAccounts.plist")
        }
    }

    private func query(_ sql: String) throws -> [[String: MetadataValue]] {
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
        return try JSONDecoder().decode([[String: MetadataValue]].self, from: data)
    }

    private func tableExists(_ table: String) throws -> Bool {
        guard !table.isEmpty else { return false }
        let rows = try query("SELECT name FROM sqlite_master WHERE type = 'table' AND name = '\(sqlEscape(table))' LIMIT 1;")
        return !rows.isEmpty
    }

    private func columns(in table: String) throws -> Set<String> {
        let rows = try query("PRAGMA table_info(\(table));")
        return Set(rows.compactMap { $0["name"]?.stringValue })
    }

    private func validateSQLiteStore(featureName: String) throws {
        guard FileManager.default.fileExists(atPath: database.path) else { throw LocalInventoryError.missingStore(database.path) }
        do {
            _ = try query("PRAGMA schema_version;")
        } catch {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "\(featureName) store is not a readable SQLite database for this command")
        }
    }

    private func requireConfirmationIfNeeded(command: MetadataCommand, options: MetadataOptions) throws {
        let sensitive: [MetadataCommand: String] = [
            .healthSummary: "icloud-cli health summary",
            .mailRecent: "icloud-cli mail recent",
            .safariCloudTabsList: "icloud-cli safari cloud-tabs list",
        ]
        if let commandName = sensitive[command], !options.confirmSensitive {
            throw LocalInventoryError.sensitiveConfirmationRequired(commandName)
        }
    }

    private func whereClause(for command: MetadataCommand, options: MetadataOptions) -> String {
        var filters: [String] = []
        switch command {
        case .calendarEvents:
            if let calendar = options.calendar { filters.append("calendar = '\(sqlEscape(calendar))'") }
            if let since = options.since { filters.append("startsAt >= '\(sqlEscape(since))'") }
            if let until = options.until { filters.append("startsAt <= '\(sqlEscape(until))'") }
        case .mailMailboxes:
            if let account = options.account { filters.append("account = '\(sqlEscape(account))'") }
        case .mailRecent:
            if let account = options.account { filters.append("account = '\(sqlEscape(account))'") }
            if let mailbox = options.mailbox { filters.append("mailbox = '\(sqlEscape(mailbox))'") }
        case .booksList:
            if let collection = options.collection { filters.append("collection = '\(sqlEscape(collection))'") }
        case .voiceMemosList, .freeformList:
            if let folder = options.folder { filters.append("folder = '\(sqlEscape(folder))'") }
            if let since = options.since { filters.append("modifiedAt >= '\(sqlEscape(since))'") }
            if let until = options.until { filters.append("modifiedAt <= '\(sqlEscape(until))'") }
        case .homeRooms, .homeAccessories, .homeScenes:
            if let home = options.home { filters.append("home = '\(sqlEscape(home))'") }
            if command == .homeAccessories, let room = options.room { filters.append("room = '\(sqlEscape(room))'") }
        case .musicTracks:
            if let playlist = options.playlist { filters.append("playlist = '\(sqlEscape(playlist))'") }
            if options.downloadedOnly { filters.append("cloudStatus = 'downloaded'") }
            if options.cloudOnly { filters.append("cloudStatus = 'cloud-only'") }
        case .notesFolders:
            if let account = options.account { filters.append("account = '\(sqlEscape(account))'") }
        case .remindersFlagged:
            filters.append("isFlagged = 1")
            filters.append("isCompleted = 0")
        case .remindersToday:
            filters.append("dueAt <= date('now', '+1 day')")
            filters.append("isCompleted = 0")
        case .remindersScheduled:
            if let since = options.since { filters.append("dueAt >= '\(sqlEscape(since))'") }
            if let until = options.until { filters.append("dueAt <= '\(sqlEscape(until))'") }
        case .remindersAssigned:
            filters.append("assignedToMe = 1")
            filters.append("isCompleted = 0")
        case .safariCloudTabsList:
            if let device = options.device { filters.append("deviceName = '\(sqlEscape(device))'") }
        case .safariExtensionsList:
            if let profile = options.profile { filters.append("profile = '\(sqlEscape(profile))'") }
        default:
            break
        }
        return filters.isEmpty ? "" : " WHERE " + filters.joined(separator: " AND ")
    }

    private func orderClause(for command: MetadataCommand) -> String {
        switch command {
        case .calendarEvents: return " ORDER BY startsAt ASC"
        case .mailRecent: return " ORDER BY sentAt DESC"
        case .freeformList, .voiceMemosList: return " ORDER BY modifiedAt DESC"
        case .safariCloudTabsList: return " ORDER BY deviceName ASC, lastSyncedAt DESC"
        default: return ""
        }
    }

    private func redact(row: MetadataRow, command: MetadataCommand, options: MetadataOptions) -> MetadataRow {
        var fields = row.fields
        if command == .calendarEvents {
            if !options.includeAttendees { fields.removeValue(forKey: "attendees") }
            if !options.includeNotes { fields.removeValue(forKey: "notes") }
        }
        if command == .safariCloudTabsList {
            if !options.includeURLs {
                fields.removeValue(forKey: "url")
            } else if !options.raw, let rawURL = fields["url"]?.stringValue {
                fields["url"] = .string(redactURL(rawURL))
            }
        }
        if command == .weatherFavorites, !options.includeCoordinates {
            fields.removeValue(forKey: "latitude")
            fields.removeValue(forKey: "longitude")
        }
        if command == .findMyDevices || command == .findMyPeople, !options.includeCoordinates {
            fields.removeValue(forKey: "latitude")
            fields.removeValue(forKey: "longitude")
        }
        if command == .remindersFlagged || command == .remindersToday || command == .remindersScheduled || command == .remindersAssigned {
            if !options.includeNotes { fields.removeValue(forKey: "notes") }
        }
        if command == .booksList, !options.includeHighlights {
            fields.removeValue(forKey: "highlightCount")
        }
        return MetadataRow(kind: row.kind, fields: fields)
    }
}

public struct AccountServiceState: Codable, Equatable, Sendable {
    public let name: String
    public let enabled: Bool?
}

public struct AccountStatus: Codable, Equatable, Sendable {
    public let signedIn: Bool
    public let appleID: String?
    public let accountType: String?
    public let services: [AccountServiceState]
    public let twoFactorEnabled: Bool?
    public let advancedDataProtectionEnabled: Bool?
}

public struct AccountStatusReader: Sendable {
    public let cacheFile: URL

    public init(cacheFile: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/MobileMeAccounts.plist")) {
        self.cacheFile = cacheFile
    }

    public func readStatus() throws -> AccountStatus {
        guard let plist = NSDictionary(contentsOf: cacheFile) else { throw LocalInventoryError.missingStore(cacheFile.path) }
        let appleID = stringValue(plist["AccountID"] ?? plist["DSIDAccountEmail"] ?? plist["appleID"] ?? plist["email"])
        let type = stringValue(plist["AccountType"] ?? plist["accountType"])
        return AccountStatus(
            signedIn: appleID != nil,
            appleID: appleID,
            accountType: type,
            services: serviceStates(from: plist),
            twoFactorEnabled: boolValue(plist["twoFactorEnabled"] ?? plist["2FAEnabled"]),
            advancedDataProtectionEnabled: boolValue(plist["advancedDataProtectionEnabled"] ?? plist["ADPEnabled"])
        )
    }

    private func serviceStates(from plist: NSDictionary) -> [AccountServiceState] {
        if let services = plist["Services"] as? [NSDictionary] {
            return services.compactMap { service in
                guard let name = stringValue(service["Name"] ?? service["name"] ?? service["serviceName"]) else { return nil }
                return AccountServiceState(name: name, enabled: boolValue(service["Enabled"] ?? service["enabled"]))
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        let names = ["Drive", "Photos", "Mail", "Keychain", "Find My", "iCloud Backup", "Calendar", "Contacts", "Reminders", "Notes", "Safari", "News", "Stocks", "Home", "Health", "Wallet"]
        return names.map { name in
            let key = name.replacingOccurrences(of: " ", with: "")
            return AccountServiceState(name: name, enabled: boolValue(plist[key] ?? plist["\(key)Enabled"]))
        }
    }
}

public struct FamilyMember: Codable, Equatable, Sendable {
    public let displayName: String
    public let role: String?
    public let email: String?
    public let purchaseSharing: Bool?
}

public struct SharedSubscription: Codable, Equatable, Sendable {
    public let name: String
    public let tier: String?
}

public struct FamilyStatus: Codable, Equatable, Sendable {
    public let configured: Bool
    public let organizer: String?
    public let members: [FamilyMember]
    public let subscriptions: [SharedSubscription]
}

public struct FamilyStatusReader: Sendable {
    public let cacheFile: URL

    public init(cacheFile: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/MobileMeAccounts.plist")) {
        self.cacheFile = cacheFile
    }

    public func readStatus() throws -> FamilyStatus {
        guard let plist = NSDictionary(contentsOf: cacheFile) else { throw LocalInventoryError.missingStore(cacheFile.path) }
        let family = plist["Family"] as? NSDictionary
        let members = (family?["members"] as? [NSDictionary] ?? plist["FamilyMembers"] as? [NSDictionary] ?? []).compactMap { member -> FamilyMember? in
            guard let displayName = stringValue(member["displayName"] ?? member["name"]) else { return nil }
            return FamilyMember(displayName: displayName, role: stringValue(member["role"]), email: stringValue(member["email"] ?? member["appleID"]), purchaseSharing: boolValue(member["purchaseSharing"]))
        }
        let subscriptions = (family?["subscriptions"] as? [NSDictionary] ?? plist["SharedSubscriptions"] as? [NSDictionary] ?? []).compactMap { subscription -> SharedSubscription? in
            guard let name = stringValue(subscription["name"] ?? subscription["service"]) else { return nil }
            return SharedSubscription(name: name, tier: stringValue(subscription["tier"]))
        }
        return FamilyStatus(
            configured: boolValue(family?["configured"] ?? plist["FamilyConfigured"]) ?? !members.isEmpty,
            organizer: stringValue(family?["organizer"] ?? plist["FamilyOrganizer"]),
            members: members,
            subscriptions: subscriptions
        )
    }
}

public struct BackupDeviceStatus: Codable, Equatable, Sendable {
    public let deviceName: String
    public let model: String?
    public let backupEnabled: Bool?
    public let lastBackupAt: String?
    public let backupSizeBytes: Int?
    public let blocker: String?
}

public struct BackupStatusReader: Sendable {
    public let cacheFile: URL

    public init(cacheFile: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/MobileMeAccounts.plist")) {
        self.cacheFile = cacheFile
    }

    public func readStatus() throws -> [BackupDeviceStatus] {
        guard let plist = NSDictionary(contentsOf: cacheFile) else { throw LocalInventoryError.missingStore(cacheFile.path) }
        let backups = plist["Backups"] as? [NSDictionary] ?? plist["BackupDevices"] as? [NSDictionary] ?? []
        return backups.compactMap { backup in
            guard let name = stringValue(backup["deviceName"] ?? backup["name"]) else { return nil }
            return BackupDeviceStatus(
                deviceName: name,
                model: stringValue(backup["model"]),
                backupEnabled: boolValue(backup["backupEnabled"] ?? backup["enabled"]),
                lastBackupAt: stringValue(backup["lastBackupAt"] ?? backup["lastSuccessfulBackupAt"]),
                backupSizeBytes: intValue(backup["backupSizeBytes"] ?? backup["sizeBytes"]),
                blocker: stringValue(backup["blocker"] ?? backup["nextBackupBlocker"])
            )
        }
    }
}

public struct PermissionProbe: Codable, Equatable, Sendable {
    public let command: String
    public let paths: [String]
    public let status: String
    public let hint: String
}

public struct PermissionsDoctor: Sendable {
    public init() {}

    public func diagnose() -> [PermissionProbe] {
        probeMatrix().map { item in
            let redacted = item.paths.map(redactHomePath)
            let missing = item.paths.filter { !FileManager.default.fileExists(atPath: $0) }
            let unreadable = item.paths.filter { FileManager.default.fileExists(atPath: $0) && !FileManager.default.isReadableFile(atPath: $0) }
            let status: String
            if item.needsConfirmation {
                status = "needs-confirm-sensitive"
            } else if !unreadable.isEmpty {
                status = "missing-fda"
            } else if missing.count == item.paths.count {
                status = "path-not-found"
            } else {
                status = "ok"
            }
            return PermissionProbe(command: item.command, paths: redacted, status: status, hint: hint(for: status))
        }
    }

    private func probeMatrix() -> [(command: String, paths: [String], needsConfirmation: Bool)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            ("safari tabs", [home.appendingPathComponent("Library/Safari").path], false),
            ("safari history", [home.appendingPathComponent("Library/Safari/History.db").path], true),
            ("messages recent", [home.appendingPathComponent("Library/Messages/chat.db").path], true),
            ("health summary", [home.appendingPathComponent("Library/Health/healthdb_secure.sqlite").path], true),
            ("mail recent", [home.appendingPathComponent("Library/Mail").path], true),
            ("notes list", [home.appendingPathComponent("Library/Group Containers/group.com.apple.notes/NoteStore.sqlite").path], false),
            ("drive list", [home.appendingPathComponent("Library/Mobile Documents").path], false),
            ("photos list", [home.appendingPathComponent("Pictures/Photos Library.photoslibrary").path], false),
        ]
    }

    private func hint(for status: String) -> String {
        switch status {
        case "missing-fda": return "Grant Full Disk Access to the calling terminal or agent process."
        case "path-not-found": return "The local cache path has not been created or the service is not enabled on this Mac."
        case "needs-confirm-sensitive": return "The command intentionally requires --confirm-sensitive before reading payload metadata."
        default: return "Readable local source path."
        }
    }
}

public struct SnapshotEntry: Codable, Equatable, Sendable {
    public let command: String
    public let ok: Bool
    public let summary: String
}

public struct SnapshotReport: Codable, Equatable, Sendable {
    public let generatedAt: String
    public let redaction: String
    public let entries: [SnapshotEntry]
}

public struct SnapshotBuilder: Sendable {
    public init() {}

    public func build(options: MetadataOptions) -> SnapshotReport {
        let commands = options.include.isEmpty ? ["storage-status", "devices-list", "focus-status", "drive-list", "cache-status"] : options.include
        let entries = commands.map { command -> SnapshotEntry in
            do {
                return try entry(for: command)
            } catch {
                return SnapshotEntry(command: command, ok: false, summary: error.localizedDescription)
            }
        }
        return SnapshotReport(generatedAt: ISO8601DateFormatter().string(from: Date()), redaction: options.redaction.rawValue, entries: entries)
    }

    private func entry(for command: String) throws -> SnapshotEntry {
        switch command {
        case "storage-status":
            let status = try ICloudStorageStatusReader().readStatus()
            return SnapshotEntry(command: command, ok: true, summary: "\(status.usedBytes)/\(status.totalBytes) bytes used")
        case "devices-list":
            let devices = try ICloudDevicesReader().listDevices()
            return SnapshotEntry(command: command, ok: true, summary: "\(devices.count) devices")
        case "focus-status":
            let status = try FocusStatusReader().readStatus()
            return SnapshotEntry(command: command, ok: true, summary: status.activeFocus ?? "none")
        case "drive-list":
            let files = try ICloudDriveInventoryReader().listFiles(depth: 1)
            return SnapshotEntry(command: command, ok: true, summary: "\(files.count) files")
        case "cache-status":
            let status = try CacheWatchStore().status()
            return SnapshotEntry(command: command, ok: true, summary: "\(status.count) cache files")
        default:
            throw CacheWatchError.missingCommand(command)
        }
    }
}

public struct FinderTag: Codable, Equatable, Sendable {
    public let name: String
    public let color: String?
    public let favorite: Bool
    public let displayOrder: Int
}

public struct TaggedDriveItem: Codable, Equatable, Sendable {
    public let path: String
    public let modifiedAt: Date?
    public let iCloudStatus: ICloudFileStatus
}

public struct FinderTagsReader: Sendable {
    public let preferencesFile: URL
    public let driveRoot: URL

    public init(
        preferencesFile: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/SyncedPreferences/com.apple.finder.plist"),
        driveRoot: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents")
    ) {
        self.preferencesFile = preferencesFile
        self.driveRoot = driveRoot
    }

    public func listTags() throws -> [FinderTag] {
        guard let plist = NSDictionary(contentsOf: preferencesFile) else { throw LocalInventoryError.missingStore(preferencesFile.path) }
        let favorites = plist["FavoriteTagNames"] as? [String] ?? []
        let colors = plist["TagColorDictionary"] as? [String: String] ?? [:]
        let names = Array(Set(favorites + Array(colors.keys))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return names.enumerated().map { index, name in
            FinderTag(name: name, color: colors[name], favorite: favorites.contains(name), displayOrder: index)
        }
    }

    public func items(tag: String, path: String?, limit: Int) throws -> [TaggedDriveItem] {
        let scanLimit = max(200, bounded(limit, defaultValue: 50, max: 1_000) * 5)
        let files = try ICloudDriveInventoryReader(rootDirectory: driveRoot).listFiles(path: path, depth: Int.max, limit: scanLimit)
        return files
            .filter { $0.name.localizedCaseInsensitiveContains(tag) || $0.path.localizedCaseInsensitiveContains(".\(tag).") }
            .prefix(max(1, limit))
            .map { TaggedDriveItem(path: $0.path, modifiedAt: $0.modifiedAt, iCloudStatus: $0.iCloudStatus) }
    }
}

private func bounded(_ value: Int, defaultValue: Int, max: Int) -> Int {
    guard value > 0 else { return defaultValue }
    return Swift.min(value, max)
}

private func andClause(_ filters: [String?]) -> String {
    let active = filters.compactMap { $0 }.filter { !$0.isEmpty }
    return active.isEmpty ? "" : " WHERE " + active.joined(separator: " AND ")
}

private func appleDateExpression(_ column: String) -> String {
    "CASE WHEN \(column) IS NULL THEN NULL ELSE strftime('%Y-%m-%dT%H:%M:%SZ', \(column) + 978307200, 'unixepoch') END"
}

private func sqlEscape(_ value: String) -> String {
    value.replacingOccurrences(of: "'", with: "''")
}

private func coalesceExpression(candidates: [String], columns: Set<String>, alias: String, fallback: String) -> String {
    "\(coalesceRawExpression(candidates: candidates, columns: columns, fallback: fallback)) AS \(alias)"
}

private func coalesceRawExpression(candidates: [String], columns: Set<String>, tableAlias: String? = nil, fallback: String) -> String {
    let prefix = tableAlias.map { "\($0)." } ?? ""
    let available = candidates.filter { columns.contains($0) }.map { "\(prefix)\($0)" }
    return "COALESCE(\((available + [fallback]).joined(separator: ", ")))"
}

private func firstExisting(in directory: URL, matching predicate: (URL) -> Bool) -> URL? {
    guard let contents = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) else {
        return nil
    }
    return contents
        .filter(predicate)
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        .first
}

private func redactURL(_ raw: String) -> String {
    guard let components = URLComponents(string: raw), let scheme = components.scheme, let host = components.host else {
        return raw
    }
    return "\(scheme)://\(host)"
}

private func stringValue(_ value: Any?) -> String? {
    if let string = value as? String, !string.isEmpty { return string }
    return nil
}

private func boolValue(_ value: Any?) -> Bool? {
    if let bool = value as? Bool { return bool }
    if let number = value as? NSNumber { return number.boolValue }
    if let string = value as? String { return ["true", "yes", "1"].contains(string.lowercased()) }
    return nil
}

private func intValue(_ value: Any?) -> Int? {
    if let number = value as? NSNumber { return number.intValue }
    if let string = value as? String { return Int(string) }
    return nil
}

private func redactHomePath(_ path: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path == home { return "~" }
    if path.hasPrefix(home + "/") { return "~/" + String(path.dropFirst(home.count + 1)) }
    return path
}
