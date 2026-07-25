import Foundation

public enum ArchiveFreshness: String, Codable, Equatable, Sendable {
    case fresh
    case stale
    case neverSucceeded = "never-succeeded"
}

public struct ArchiveFailure: Codable, Equatable, Sendable {
    public let code: String
    public let guidance: String

    public init(code: String, guidance: String) {
        self.code = code
        self.guidance = guidance
    }
}

public indirect enum ArchiveValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([ArchiveValue])
    case object([String: ArchiveValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int.self) { self = .int(value) }
        else if let value = try? container.decode(Double.self) { self = .double(value) }
        else if let value = try? container.decode([ArchiveValue].self) { self = .array(value) }
        else if let value = try? container.decode([String: ArchiveValue].self) { self = .object(value) }
        else { self = .string(try container.decode(String.self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}

public struct ArchiveInputRecord: Codable, Equatable, Sendable {
    public let id: String
    public let sourceModifiedAt: String?
    public let fields: [String: ArchiveValue]

    public init(id: String, sourceModifiedAt: String?, fields: [String: ArchiveValue]) {
        self.id = id
        self.sourceModifiedAt = sourceModifiedAt
        self.fields = fields
    }
}

public struct ArchiveSyncBatch: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let providerId: String
    public let providerSchemaVersion: String
    public let sourceFingerprint: String
    public let cursor: String?
    public let records: [ArchiveInputRecord]
    public let deletedIds: [String]
    public let failure: ArchiveFailure?
    public let sensitiveFields: [String]?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, providerId, providerSchemaVersion, sourceFingerprint, cursor, records, deletedIds, failure
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(String.self, forKey: .schemaVersion)
        providerId = try values.decode(String.self, forKey: .providerId)
        providerSchemaVersion = try values.decode(String.self, forKey: .providerSchemaVersion)
        sourceFingerprint = try values.decode(String.self, forKey: .sourceFingerprint)
        cursor = try values.decodeIfPresent(String.self, forKey: .cursor)
        records = try values.decode([ArchiveInputRecord].self, forKey: .records)
        deletedIds = try values.decode([String].self, forKey: .deletedIds)
        failure = try values.decodeIfPresent(ArchiveFailure.self, forKey: .failure)
        sensitiveFields = nil
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(providerId, forKey: .providerId)
        try values.encode(providerSchemaVersion, forKey: .providerSchemaVersion)
        try values.encode(sourceFingerprint, forKey: .sourceFingerprint)
        try values.encodeIfPresent(cursor, forKey: .cursor)
        try values.encode(records, forKey: .records)
        try values.encode(deletedIds, forKey: .deletedIds)
        try values.encodeIfPresent(failure, forKey: .failure)
    }

    public init(
        schemaVersion: String,
        providerId: String,
        providerSchemaVersion: String,
        sourceFingerprint: String,
        cursor: String?,
        records: [ArchiveInputRecord],
        deletedIds: [String],
        failure: ArchiveFailure?,
        sensitiveFields: [String]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.providerId = providerId
        self.providerSchemaVersion = providerSchemaVersion
        self.sourceFingerprint = sourceFingerprint
        self.cursor = cursor
        self.records = records
        self.deletedIds = deletedIds
        self.failure = failure
        self.sensitiveFields = sensitiveFields
    }
}

public struct ArchivedRecord: Codable, Equatable, Sendable {
    public let id: String
    public let sourceModifiedAt: String?
    public let archivedAt: String
    public let tombstonedAt: String?
    public let fields: [String: ArchiveValue]?
}

public struct ProviderArchiveDocument: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let providerId: String
    public let providerSchemaVersion: String
    public let cursor: String?
    public let sourceFingerprint: String?
    public let lastAttemptAt: String?
    public let lastSuccessAt: String?
    public let freshness: ArchiveFreshness
    public let activeItemCount: Int
    public let tombstoneCount: Int
    public let totalRecordCount: Int
    public let failure: ArchiveFailure?
    public let records: [ArchivedRecord]
}

public struct ArchiveProviderStatus: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let providerId: String
    public let providerSchemaVersion: String
    public let cursor: String?
    public let sourceFingerprint: String?
    public let lastAttemptAt: String?
    public let lastSuccessAt: String?
    public let freshness: ArchiveFreshness
    public let activeItemCount: Int
    public let tombstoneCount: Int
    public let totalRecordCount: Int
    public let failure: ArchiveFailure?
}

public struct ArchiveSyncResult: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let providerId: String
    public let state: CrawlState
    public let scannedCount: Int
    public let upsertedCount: Int
    public let tombstonedCount: Int
    public let status: ArchiveProviderStatus
}

public struct ArchiveRetentionPolicy: Codable, Equatable, Sendable {
    public let tombstoneLifetimeSeconds: TimeInterval
    public let maximumRecords: Int

    public init(tombstoneLifetimeSeconds: TimeInterval = 30 * 86_400, maximumRecords: Int = 100_000) {
        self.tombstoneLifetimeSeconds = max(0, tombstoneLifetimeSeconds)
        self.maximumRecords = max(1, maximumRecords)
    }
}

public enum ProviderArchiveError: Error, LocalizedError, Equatable {
    case invalidBatchSchema(String)
    case invalidProviderId(String)
    case providerNotArchivable(String)
    case providerMismatch(expected: String, actual: String)
    case sensitiveField(String)
    case missingArchive(String)
    case inputTooLarge(Int64)
    case unsupportedArchiveSchema(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBatchSchema(let schema): return "Unsupported archive sync schema: \(schema)"
        case .invalidProviderId(let provider): return "Invalid archive provider id: \(provider)"
        case .providerNotArchivable(let provider): return "Provider is not approved for metadata archiving: \(provider)"
        case .providerMismatch(let expected, let actual): return "Archive batch provider mismatch: expected \(expected), found \(actual)"
        case .sensitiveField(let field): return "Archive batch contains a high-sensitivity field that is not opted in: \(field)"
        case .missingArchive(let provider): return "No provider archive found for \(provider)"
        case .inputTooLarge(let bytes): return "Archive sync input exceeds the 16 MiB safety limit: \(bytes) bytes"
        case .unsupportedArchiveSchema(let schema): return "Unsupported provider archive schema: \(schema)"
        }
    }
}

enum ArchivePrivacy {
    private static let sensitiveFieldRoots = ["body", "content", "media", "pixel", "audio", "attachment"]

    static func isSensitiveField(_ key: String) -> Bool {
        let normalized = key.lowercased().filter { $0.isLetter || $0.isNumber }
        return sensitiveFieldRoots.contains { normalized.contains($0) }
    }
}

public struct ProviderArchiveStore: Sendable {
    public let rootDirectory: URL
    public let retention: ArchiveRetentionPolicy
    public let freshnessLifetimeSeconds: TimeInterval
    private let now: @Sendable () -> Date
    private let monotonic: @Sendable () -> TimeInterval

    public init(
        rootDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".icloud-cli/archives"),
        retention: ArchiveRetentionPolicy = ArchiveRetentionPolicy(),
        freshnessLifetimeSeconds: TimeInterval = 3_600,
        now: @escaping @Sendable () -> Date = { Date() },
        monotonic: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.rootDirectory = rootDirectory
        self.retention = retention
        self.freshnessLifetimeSeconds = max(1, freshnessLifetimeSeconds)
        self.now = now
        self.monotonic = monotonic
    }

    public func sync(_ batch: ArchiveSyncBatch, budget: CrawlBudget) throws -> ArchiveSyncResult {
        try validate(batch)
        try ensureRootDirectory()
        let attemptedAt = now()
        let attemptedAtString = iso8601(attemptedAt)
        let startedAt = monotonic()
        var document = try loadOrCreate(batch: batch)
        var records = Dictionary(uniqueKeysWithValues: document.records.map { ($0.id, $0) })
        var scannedCount = 0
        var upsertedCount = 0
        var tombstonedCount = 0
        var budgetFailure: ArchiveFailure?

        for record in batch.records.sorted(by: { $0.id < $1.id }) {
            guard withinBudget(scannedCount: scannedCount, startedAt: startedAt, budget: budget) else {
                budgetFailure = budgetExceededFailure(startedAt: startedAt, budget: budget)
                break
            }
            scannedCount += 1
            if let existing = records[record.id], existing.tombstonedAt == nil,
               existing.sourceModifiedAt == record.sourceModifiedAt, existing.fields == record.fields {
                continue
            }
            records[record.id] = ArchivedRecord(id: record.id, sourceModifiedAt: record.sourceModifiedAt, archivedAt: attemptedAtString, tombstonedAt: nil, fields: record.fields)
            upsertedCount += 1
        }

        if budgetFailure == nil {
            for id in Array(Set(batch.deletedIds)).sorted() {
                guard withinBudget(scannedCount: scannedCount, startedAt: startedAt, budget: budget) else {
                    budgetFailure = budgetExceededFailure(startedAt: startedAt, budget: budget)
                    break
                }
                scannedCount += 1
                guard let existing = records[id], existing.tombstonedAt == nil else { continue }
                records[id] = ArchivedRecord(id: id, sourceModifiedAt: existing.sourceModifiedAt, archivedAt: existing.archivedAt, tombstonedAt: attemptedAtString, fields: nil)
                tombstonedCount += 1
            }
        }

        let failure = batch.failure.map(redactedFailure) ?? budgetFailure
        let completed = failure == nil
        let retained = applyRetention(Array(records.values), now: attemptedAt)
        let lastSuccessAt = completed ? attemptedAtString : document.lastSuccessAt
        let activeItemCount = retained.filter { $0.tombstonedAt == nil }.count
        document = ProviderArchiveDocument(
            schemaVersion: "icloud-cli.archive.v1",
            providerId: batch.providerId,
            providerSchemaVersion: batch.providerSchemaVersion,
            cursor: completed ? batch.cursor : document.cursor,
            sourceFingerprint: completed ? batch.sourceFingerprint : document.sourceFingerprint,
            lastAttemptAt: attemptedAtString,
            lastSuccessAt: lastSuccessAt,
            freshness: freshness(lastSuccessAt: lastSuccessAt, now: attemptedAt),
            activeItemCount: activeItemCount,
            tombstoneCount: retained.count - activeItemCount,
            totalRecordCount: retained.count,
            failure: failure,
            records: retained
        )
        try write(document)
        return ArchiveSyncResult(
            schemaVersion: "icloud-cli.archive-sync-result.v1",
            providerId: batch.providerId,
            state: completed ? .complete : .partial,
            scannedCount: scannedCount,
            upsertedCount: upsertedCount,
            tombstonedCount: tombstonedCount,
            status: status(for: document, now: attemptedAt)
        )
    }

    public func read(providerId: String) throws -> ProviderArchiveDocument {
        try validateProviderId(providerId)
        let url = fileURL(providerId: providerId)
        guard FileManager.default.fileExists(atPath: url.path) else { throw ProviderArchiveError.missingArchive(providerId) }
        let data = try Data(contentsOf: url)
        if let document = try? JSONDecoder().decode(ProviderArchiveDocument.self, from: data) {
            guard document.schemaVersion == "icloud-cli.archive.v1" else { throw ProviderArchiveError.unsupportedArchiveSchema(document.schemaVersion) }
            return document
        }
        let legacy = try JSONDecoder().decode(LegacyArchiveV0.self, from: data)
        guard legacy.schemaVersion == "icloud-cli.archive.v0" else { throw ProviderArchiveError.unsupportedArchiveSchema(legacy.schemaVersion) }
        let migrated = ProviderArchiveDocument(
            schemaVersion: "icloud-cli.archive.v1",
            providerId: legacy.providerId,
            providerSchemaVersion: legacy.providerSchemaVersion,
            cursor: legacy.cursor,
            sourceFingerprint: legacy.sourceFingerprint,
            lastAttemptAt: legacy.updatedAt,
            lastSuccessAt: legacy.updatedAt,
            freshness: .stale,
            activeItemCount: legacy.records.filter { $0.tombstonedAt == nil }.count,
            tombstoneCount: legacy.records.filter { $0.tombstonedAt != nil }.count,
            totalRecordCount: legacy.records.count,
            failure: nil,
            records: legacy.records
        )
        try write(migrated)
        return migrated
    }

    public func status(providerId: String) throws -> ArchiveProviderStatus {
        status(for: try read(providerId: providerId), now: now())
    }

    private func validate(_ batch: ArchiveSyncBatch) throws {
        guard batch.schemaVersion == "icloud-cli.archive-sync.v1" else { throw ProviderArchiveError.invalidBatchSchema(batch.schemaVersion) }
        try validateProviderId(batch.providerId)
        guard ProviderRegistry.manifest.providers.first(where: { $0.id == batch.providerId })?.capabilities.contains("archive-metadata") == true else {
            throw ProviderArchiveError.providerNotArchivable(batch.providerId)
        }
        let approvedSensitive = Set(batch.sensitiveFields ?? [])
        for record in batch.records {
            // This internal opt-in is limited to the canonical Messages body field.
            // Aliases must remain fail-closed.
            if let field = sensitiveField(in: record.fields), !(batch.providerId == "messages" && field == "body" && approvedSensitive.contains("body")) {
                throw ProviderArchiveError.sensitiveField(field)
            }
        }
    }

    private func validateProviderId(_ providerId: String) throws {
        let allowed = providerId.unicodeScalars.allSatisfy { CharacterSet.lowercaseLetters.contains($0) || CharacterSet.decimalDigits.contains($0) || $0 == "-" }
        guard allowed, !providerId.isEmpty else { throw ProviderArchiveError.invalidProviderId(providerId) }
    }

    private func sensitiveField(in fields: [String: ArchiveValue]) -> String? {
        for (key, value) in fields {
            if ArchivePrivacy.isSensitiveField(key) { return key }
            if let match = sensitiveField(in: value) { return match }
        }
        return nil
    }

    private func sensitiveField(in value: ArchiveValue) -> String? {
        switch value {
        case .object(let fields): return sensitiveField(in: fields)
        case .array(let values):
            for value in values {
                if let match = sensitiveField(in: value) { return match }
            }
            return nil
        default: return nil
        }
    }

    private func redactedFailure(_ failure: ArchiveFailure) -> ArchiveFailure {
        let allowed = failure.code.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return ArchiveFailure(code: String(allowed.prefix(64)).isEmpty ? "provider-error" : String(allowed.prefix(64)), guidance: "Retry the provider with a narrower scope or inspect it directly for local diagnostic details.")
    }

    private func loadOrCreate(batch: ArchiveSyncBatch) throws -> ProviderArchiveDocument {
        if FileManager.default.fileExists(atPath: fileURL(providerId: batch.providerId).path) {
            return try read(providerId: batch.providerId)
        }
        return ProviderArchiveDocument(schemaVersion: "icloud-cli.archive.v1", providerId: batch.providerId, providerSchemaVersion: batch.providerSchemaVersion, cursor: nil, sourceFingerprint: nil, lastAttemptAt: nil, lastSuccessAt: nil, freshness: .neverSucceeded, activeItemCount: 0, tombstoneCount: 0, totalRecordCount: 0, failure: nil, records: [])
    }

    private func withinBudget(scannedCount: Int, startedAt: TimeInterval, budget: CrawlBudget) -> Bool {
        scannedCount < budget.scanLimit && Int((monotonic() - startedAt) * 1_000) < budget.wallClockLimitMilliseconds
    }

    private func budgetExceededFailure(startedAt: TimeInterval, budget: CrawlBudget) -> ArchiveFailure {
        let timedOut = Int((monotonic() - startedAt) * 1_000) >= budget.wallClockLimitMilliseconds
        return ArchiveFailure(
            code: timedOut ? "timeout" : "scan-limit",
            guidance: timedOut ? "Increase the explicit sync timeout or reduce the input batch." : "Resume with the remaining records or increase the explicit scan limit."
        )
    }

    private func applyRetention(_ records: [ArchivedRecord], now: Date) -> [ArchivedRecord] {
        let tombstoneFloor = now.addingTimeInterval(-retention.tombstoneLifetimeSeconds)
        return records
            .filter { record in
                guard let tombstonedAt = record.tombstonedAt, let date = ISO8601DateFormatter().date(from: tombstonedAt) else { return true }
                return date >= tombstoneFloor
            }
            .sorted { ($0.archivedAt, $0.id) > ($1.archivedAt, $1.id) }
            .prefix(retention.maximumRecords)
            .sorted { $0.id < $1.id }
    }

    private func freshness(lastSuccessAt: String?, now: Date) -> ArchiveFreshness {
        guard let lastSuccessAt, let date = ISO8601DateFormatter().date(from: lastSuccessAt) else { return .neverSucceeded }
        return now.timeIntervalSince(date) <= freshnessLifetimeSeconds ? .fresh : .stale
    }

    private func status(for document: ProviderArchiveDocument, now: Date) -> ArchiveProviderStatus {
        return ArchiveProviderStatus(
            schemaVersion: "icloud-cli.archive-status.v1",
            providerId: document.providerId,
            providerSchemaVersion: document.providerSchemaVersion,
            cursor: document.cursor,
            sourceFingerprint: document.sourceFingerprint,
            lastAttemptAt: document.lastAttemptAt,
            lastSuccessAt: document.lastSuccessAt,
            freshness: freshness(lastSuccessAt: document.lastSuccessAt, now: now),
            activeItemCount: document.activeItemCount,
            tombstoneCount: document.tombstoneCount,
            totalRecordCount: document.totalRecordCount,
            failure: document.failure
        )
    }

    private func ensureRootDirectory() throws {
        if !FileManager.default.fileExists(atPath: rootDirectory.path) {
            try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootDirectory.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var directory = rootDirectory
        try? directory.setResourceValues(values)
    }

    private func write(_ document: ProviderArchiveDocument) throws {
        try ensureRootDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        let target = fileURL(providerId: document.providerId)
        try data.write(to: target, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
    }

    private func fileURL(providerId: String) -> URL {
        rootDirectory.appendingPathComponent(providerId).appendingPathExtension("json")
    }

    private func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

private struct LegacyArchiveV0: Codable {
    let schemaVersion: String
    let providerId: String
    let providerSchemaVersion: String
    let cursor: String?
    let sourceFingerprint: String?
    let updatedAt: String
    let records: [ArchivedRecord]
}
