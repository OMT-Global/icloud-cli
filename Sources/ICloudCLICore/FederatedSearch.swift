import Foundation

public enum FederatedSearchError: Error, LocalizedError, Equatable {
    case invalidCursor
    case sensitiveConfirmationRequired
    public var errorDescription: String? {
        switch self {
        case .invalidCursor: "Invalid federated search cursor."
        case .sensitiveConfirmationRequired: "Body search requires --include-sensitive, --include-bodies, and --confirm-sensitive."
        }
    }
}

public struct FederatedSearchRequest: Equatable, Sendable {
    public let query: String
    public let providers: [String]
    public let since: String?
    public let until: String?
    public let limit: Int
    public let cursor: String?
    public let includeSensitive: Bool
    public let includeBodies: Bool
    public let confirmSensitive: Bool

    public init(query: String, providers: [String], since: String?, until: String?, limit: Int, cursor: String?, includeSensitive: Bool, includeBodies: Bool, confirmSensitive: Bool) {
        self.query = query; self.providers = providers; self.since = since; self.until = until; self.limit = limit; self.cursor = cursor; self.includeSensitive = includeSensitive; self.includeBodies = includeBodies; self.confirmSensitive = confirmSensitive
    }
}

public struct FederatedSearchEvidence: Codable, Equatable, Sendable {
    public let source: String
    public let providerSchemaVersion: String
    public let sourceFingerprint: String?
    public let archivedAt: String
}

public struct FederatedSearchHit: Codable, Equatable, Sendable {
    public let providerId: String
    public let recordId: String
    public let timestamp: String
    public let sensitivity: ProviderSensitivity
    public let snippet: String
    public let snippetRedacted: Bool
    public let evidence: FederatedSearchEvidence
}

public struct FederatedSearchPage: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let hits: [FederatedSearchHit]
    public let nextCursor: String?
    public let totalMatched: Int
    public init(hits: [FederatedSearchHit], nextCursor: String?, totalMatched: Int) { self.schemaVersion = "icloud-cli.federated-search.v1"; self.hits = hits; self.nextCursor = nextCursor; self.totalMatched = totalMatched }
}

public struct FederatedArchiveSearch: Sendable {
    public let archiveDirectory: URL
    public init(archiveDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".icloud-cli/archives")) { self.archiveDirectory = archiveDirectory }

    public func search(_ request: FederatedSearchRequest) throws -> FederatedSearchPage {
        if request.includeBodies && (!request.includeSensitive || !request.confirmSensitive) { throw FederatedSearchError.sensitiveConfirmationRequired }
        let offset = try decodeCursor(request.cursor)
        let selected = Set(request.providers)
        let needle = request.query.lowercased()
        let since = request.since.flatMap(ISO8601DateFormatter().date)
        let until = request.until.flatMap(ISO8601DateFormatter().date)
        var hits: [FederatedSearchHit] = []

        for provider in ProviderRegistry.manifest.providers where provider.capabilities.contains("archive-metadata") {
            if !selected.isEmpty && !selected.contains(provider.id) { continue }
            if provider.sensitivity == .high && !request.includeSensitive { continue }
            guard let document = try? ProviderArchiveStore(rootDirectory: archiveDirectory).read(providerId: provider.id) else { continue }
            for record in document.records where record.tombstonedAt == nil {
                let timestamp = record.sourceModifiedAt ?? record.archivedAt
                if let date = ISO8601DateFormatter().date(from: timestamp) {
                    if let since, date < since { continue }
                    if let until, date > until { continue }
                }
                guard let fields = record.fields else { continue }
                let searchable = searchableStrings(fields, includeBodies: request.includeBodies)
                guard needle.isEmpty || ([record.id] + searchable).joined(separator: " ").lowercased().contains(needle) else { continue }
                let redacted = provider.sensitivity == .high && !request.includeBodies
                let snippet = redacted ? "[redacted high-sensitivity metadata]" : String((searchable.first(where: { $0.lowercased().contains(needle) }) ?? searchable.first ?? record.id).prefix(160))
                hits.append(FederatedSearchHit(providerId: provider.id, recordId: record.id, timestamp: timestamp, sensitivity: provider.sensitivity, snippet: snippet, snippetRedacted: redacted, evidence: FederatedSearchEvidence(source: "provider-archive", providerSchemaVersion: document.providerSchemaVersion, sourceFingerprint: document.sourceFingerprint, archivedAt: record.archivedAt)))
            }
        }
        hits.sort { ($0.timestamp, $0.providerId, $0.recordId) > ($1.timestamp, $1.providerId, $1.recordId) }
        let limit = min(max(request.limit, 1), 1_000)
        let page = Array(hits.dropFirst(min(offset, hits.count)).prefix(limit))
        let nextOffset = offset + page.count
        return FederatedSearchPage(hits: page, nextCursor: nextOffset < hits.count ? "offset:\(nextOffset)" : nil, totalMatched: hits.count)
    }

    private func decodeCursor(_ cursor: String?) throws -> Int {
        guard let cursor else { return 0 }
        guard cursor.hasPrefix("offset:"), let value = Int(cursor.dropFirst(7)), value >= 0 else { throw FederatedSearchError.invalidCursor }
        return value
    }

    private func searchableStrings(_ fields: [String: ArchiveValue], includeBodies: Bool) -> [String] {
        fields.sorted(by: { $0.key < $1.key }).flatMap { key, value -> [String] in
            strings(value, key: key, includeBodies: includeBodies)
        }
    }

    private func strings(_ value: ArchiveValue, key: String? = nil, includeBodies: Bool) -> [String] {
        if let key, ArchivePrivacy.isSensitiveField(key), !includeBodies { return [] }
        return switch value {
        case .string(let value): [value]
        case .int(let value): [String(value)]
        case .double(let value): [String(value)]
        case .bool(let value): [String(value)]
        case .null: []
        case .array(let values): values.flatMap { strings($0, includeBodies: includeBodies) }
        case .object(let values): values.sorted(by: { $0.key < $1.key }).flatMap { strings($0.value, key: $0.key, includeBodies: includeBodies) }
        }
    }
}
