import Foundation

public enum LocalInventoryError: Error, LocalizedError, Equatable {
    case missingRoot(String)
    case missingStore(String)
    case sensitiveConfirmationRequired(String)
    case sqliteFailure(String)

    public var errorDescription: String? {
        switch self {
        case .missingRoot(let path): return "Inventory root not available: \(path)"
        case .missingStore(let path): return "Inventory store not available: \(path)"
        case .sensitiveConfirmationRequired(let command):
            return "\(command) reads high-sensitivity local data; rerun with --confirm-sensitive"
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

    public func listPhotos() throws -> [PhotoAsset] {
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
        let whereClause = andClause([
            folder.map { "folderName = '\(sqlEscape($0))'" },
            modifiedSince.map { "modifiedAt >= '\(sqlEscape($0))'" },
        ])
        let bodyColumn = includeBody ? "body" : "NULL AS body"
        return try query("SELECT title, folderName, createdAt, modifiedAt, isPinned, \(bodyColumn) FROM notes\(whereClause) ORDER BY modifiedAt DESC, title ASC;")
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

    public func messageConversations() throws -> [MessageConversation] {
        try query("SELECT chatIdentifier, displayName, participantCount, lastMessageAt, messageCount FROM message_conversations ORDER BY lastMessageAt DESC;")
    }

    public func recentMessages(confirmSensitive: Bool, includeBody: Bool, since: String?, limit: Int) throws -> [MessageRecentEntry] {
        guard confirmSensitive else { throw LocalInventoryError.sensitiveConfirmationRequired("icloud-cli messages recent") }
        let floor = since ?? ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -86_400))
        let bodyColumn = includeBody ? "body" : "NULL AS body"
        return try query("SELECT chatIdentifier, sender, sentAt, isFromMe, \(bodyColumn) FROM recent_messages WHERE sentAt >= '\(sqlEscape(floor))' ORDER BY sentAt DESC LIMIT \(bounded(limit, defaultValue: 20, max: 1000));")
    }

    public func contacts(search: String?, limit: Int, includeNotes: Bool) throws -> [ContactEntry] {
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
            throw LocalInventoryError.sqliteFailure(String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if data.isEmpty { return [] }
        return try JSONDecoder().decode([T].self, from: data)
    }
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
