import Foundation

public enum MessagesArchiveError: Error, LocalizedError, Equatable {
    case bodyRetentionRequired
    case sensitiveConfirmationRequired

    public var errorDescription: String? {
        switch self {
        case .bodyRetentionRequired: "Archiving message bodies requires --body-retention-days with a positive bounded value."
        case .sensitiveConfirmationRequired: "Searching archived message bodies requires --confirm-sensitive."
        }
    }
}

public struct MessagesArchiveHit: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let messageId: String
    public let chatIdentifier: String
    public let sender: String?
    public let sentAt: String?
    public let isFromMe: Bool
    public let body: String?
}

private struct MessagesArchiveRow: Decodable {
    let messageId: String
    let chatIdentifier: String
    let sender: String?
    let sentAt: String?
    let isFromMe: Int
    let body: String?
}

public struct MessagesArchiveAdapter: Sendable {
    public let archiveDirectory: URL
    private let now: @Sendable () -> Date

    public init(archiveDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".icloud-cli/archives"), now: @escaping @Sendable () -> Date = { Date() }) {
        self.archiveDirectory = archiveDirectory
        self.now = now
    }

    public func sync(database: URL, includeBodies: Bool, bodyRetentionDays: Int?, limit: Int) throws -> ArchiveSyncResult {
        if includeBodies && (bodyRetentionDays == nil || bodyRetentionDays! <= 0 || bodyRetentionDays! > 365) {
            throw MessagesArchiveError.bodyRetentionRequired
        }
        let store = ProviderArchiveStore(
            rootDirectory: archiveDirectory,
            retention: ArchiveRetentionPolicy(tombstoneLifetimeSeconds: TimeInterval((bodyRetentionDays ?? 30) * 86_400), maximumRecords: 100_000)
        )
        let previous = try? store.read(providerId: "messages")
        let rows = try readRows(database: database, after: previous?.cursor, includeBodies: includeBodies, limit: limit)
        let currentIds = try readAllIds(database: database, limit: limit + 1)
        var records = rows.map { row in
            var fields: [String: ArchiveValue] = [
                "chatIdentifier": .string(row.chatIdentifier),
                "sender": row.sender.map(ArchiveValue.string) ?? .null,
                "sentAt": row.sentAt.map(ArchiveValue.string) ?? .null,
                "isFromMe": .bool(row.isFromMe != 0),
            ]
            if includeBodies { fields["body"] = row.body.map(ArchiveValue.string) ?? .null }
            return ArchiveInputRecord(id: row.messageId, sourceModifiedAt: row.sentAt, fields: fields)
        }
        let expiry = bodyRetentionDays.map { now().addingTimeInterval(-TimeInterval($0 * 86_400)) }
        for record in previous?.records ?? [] where record.tombstonedAt == nil {
            guard var fields = record.fields, fields["body"] != nil else { continue }
            let bodyExpired = !includeBodies || expiry.map { cutoff in
                ISO8601DateFormatter().date(from: record.archivedAt).map { archivedAt in archivedAt < cutoff } ?? true
            } == true
            if bodyExpired {
                fields.removeValue(forKey: "body")
                records.append(ArchiveInputRecord(id: record.id, sourceModifiedAt: record.sourceModifiedAt, fields: fields))
            }
        }
        let cursor = rows.compactMap(\.sentAt).max() ?? previous?.cursor
        let values = try database.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let fingerprint = "size:\(values.fileSize ?? 0);modified:\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
        let archivedIds = Set(previous?.records.filter { $0.tombstonedAt == nil }.map(\.id) ?? [])
        let deletedIds = currentIds.count <= limit ? Array(archivedIds.subtracting(currentIds)) : []
        return try store.sync(
            ArchiveSyncBatch(schemaVersion: "icloud-cli.archive-sync.v1", providerId: "messages", providerSchemaVersion: "icloud-cli.messages-archive.v1", sourceFingerprint: fingerprint, cursor: cursor, records: records, deletedIds: deletedIds, failure: nil, sensitiveFields: includeBodies ? ["body"] : nil),
            budget: CrawlBudget(scanLimit: min(max(limit, 1), 10_000), wallClockLimitMilliseconds: 10_000)
        )
    }

    public func search(query: String, includeBodies: Bool, confirmSensitive: Bool = false, limit: Int) throws -> [MessagesArchiveHit] {
        if includeBodies && !confirmSensitive { throw MessagesArchiveError.sensitiveConfirmationRequired }
        let needle = query.lowercased()
        return try ProviderArchiveStore(rootDirectory: archiveDirectory).read(providerId: "messages").records
            .filter { $0.tombstonedAt == nil }
            .compactMap { record -> MessagesArchiveHit? in
                guard let fields = record.fields, case .string(let chatIdentifier) = fields["chatIdentifier"] else { return nil }
                let sender = fields["sender"]?.stringValue
                let sentAt = fields["sentAt"]?.stringValue
                let isFromMe = fields["isFromMe"]?.boolValue ?? false
                let body = includeBodies ? fields["body"]?.stringValue : nil
                let searchable = [record.id, chatIdentifier, sender, body].compactMap { $0 }.joined(separator: " ").lowercased()
                guard needle.isEmpty || searchable.contains(needle) else { return nil }
                return MessagesArchiveHit(schemaVersion: "icloud-cli.messages-search.v1", messageId: record.id, chatIdentifier: chatIdentifier, sender: sender, sentAt: sentAt, isFromMe: isFromMe, body: body)
            }
            .sorted { ($0.sentAt ?? "", $0.messageId) > ($1.sentAt ?? "", $1.messageId) }
            .prefix(min(max(limit, 1), 1_000))
            .map { $0 }
    }

    private func readRows(database: URL, after cursor: String?, includeBodies: Bool, limit: Int) throws -> [MessagesArchiveRow] {
        let engine = SQLiteSnapshotQueryEngine(source: database)
        let floor = cursor.map { "WHERE sentAt > '\(sqlLiteral($0))'" } ?? ""
        let body = includeBodies ? "body" : "NULL AS body"
        do {
            return try engine.query("SELECT messageId, chatIdentifier, sender, sentAt, isFromMe, \(body) FROM recent_messages \(floor) ORDER BY sentAt ASC LIMIT \(min(max(limit, 1), 10000));")
        } catch LocalInventoryError.unsupportedSchema {
            throw LocalInventoryError.unsupportedSchema(store: database.path, detail: "unsupported Messages schema")
        } catch {
            let appleFloor = cursor.map { "WHERE m.date > \(Int64($0) ?? 0)" } ?? ""
            let appleBody = includeBodies ? "m.text" : "NULL"
            return try engine.query("""
                SELECT CAST(m.ROWID AS TEXT) AS messageId,
                       COALESCE(c.chat_identifier, c.guid, h.id, 'unknown') AS chatIdentifier,
                       h.id AS sender, CAST(m.date AS TEXT) AS sentAt,
                       COALESCE(m.is_from_me, 0) AS isFromMe, \(appleBody) AS body
                FROM message m
                LEFT JOIN handle h ON h.ROWID = m.handle_id
                LEFT JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
                LEFT JOIN chat c ON c.ROWID = cmj.chat_id
                \(appleFloor) ORDER BY m.date ASC LIMIT \(min(max(limit, 1), 10000));
                """)
        }
    }

    private func readAllIds(database: URL, limit: Int) throws -> Set<String> {
        struct Identifier: Decodable { let id: String }
        let engine = SQLiteSnapshotQueryEngine(source: database)
        if let rows: [Identifier] = try? engine.query("SELECT messageId AS id FROM recent_messages ORDER BY messageId LIMIT \(limit);") {
            return Set(rows.map(\.id))
        }
        let rows: [Identifier] = try engine.query("SELECT CAST(ROWID AS TEXT) AS id FROM message ORDER BY ROWID LIMIT \(limit);")
        return Set(rows.map(\.id))
    }

    private func sqlLiteral(_ value: String) -> String { value.replacingOccurrences(of: "'", with: "''") }
}

private extension ArchiveValue {
    var stringValue: String? { if case .string(let value) = self { value } else { nil } }
    var boolValue: Bool? { if case .bool(let value) = self { value } else { nil } }
}
