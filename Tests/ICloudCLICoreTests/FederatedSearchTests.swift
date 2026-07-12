import Foundation
import Testing
@testable import ICloudCLICore

@Test func federatedSearchRanksPagesAndPreservesProvenance() throws {
    let root = try federatedSearchFixture("ranking")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = ProviderArchiveStore(rootDirectory: root)
    _ = try store.sync(searchBatch(provider: "drive", records: [searchRecord("d1", "Quarterly plan", "2026-07-10T10:00:00Z")]), budget: .defaultPolling)
    _ = try store.sync(searchBatch(provider: "shortcuts", records: [searchRecord("s1", "Plan review", "2026-07-11T10:00:00Z")]), budget: .defaultPolling)

    let engine = FederatedArchiveSearch(archiveDirectory: root)
    let first = try engine.search(FederatedSearchRequest(query: "plan", providers: [], since: nil, until: nil, limit: 1, cursor: nil, includeSensitive: false, includeBodies: false, confirmSensitive: false))
    #expect(first.hits.map(\.recordId) == ["s1"])
    #expect(first.hits.first?.evidence.providerSchemaVersion == "shortcuts.v1")
    #expect(first.nextCursor != nil)
    let second = try engine.search(FederatedSearchRequest(query: "plan", providers: [], since: nil, until: nil, limit: 1, cursor: first.nextCursor, includeSensitive: false, includeBodies: false, confirmSensitive: false))
    #expect(second.hits.map(\.recordId) == ["d1"])
}

@Test func federatedSearchRequiresExplicitSensitiveAndBodyOptIn() throws {
    let root = try federatedSearchFixture("sensitive")
    defer { try? FileManager.default.removeItem(at: root) }
    let adapter = MessagesArchiveAdapter(archiveDirectory: root)
    let db = root.appendingPathComponent("chat.db")
    try makeFederatedMessagesDB(db)
    _ = try adapter.sync(database: db, includeBodies: true, bodyRetentionDays: 7, limit: 10)
    let engine = FederatedArchiveSearch(archiveDirectory: root)

    let hidden = try engine.search(FederatedSearchRequest(query: "secret", providers: [], since: nil, until: nil, limit: 10, cursor: nil, includeSensitive: false, includeBodies: false, confirmSensitive: false))
    #expect(hidden.hits.isEmpty)
    #expect(throws: FederatedSearchError.sensitiveConfirmationRequired) {
        try engine.search(FederatedSearchRequest(query: "secret", providers: ["messages"], since: nil, until: nil, limit: 10, cursor: nil, includeSensitive: true, includeBodies: true, confirmSensitive: false))
    }
    let visible = try engine.search(FederatedSearchRequest(query: "secret", providers: ["messages"], since: nil, until: nil, limit: 10, cursor: nil, includeSensitive: true, includeBodies: true, confirmSensitive: true))
    #expect(visible.hits.first?.snippetRedacted == false)
    #expect(visible.hits.first?.providerId == "messages")
}

@Test func parsesFederatedSearchFiltersAndPagination() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "search", "plan", "--provider", "drive", "--since", "2026-01-01T00:00:00Z", "--cursor", "offset:2", "--limit", "5"])
    guard case .federatedSearch(let options) = command else { Issue.record("Expected federated search"); return }
    #expect(options.query == "plan" && options.providers == ["drive"] && options.cursor == "offset:2" && options.limit == 5)
}

private func searchBatch(provider: String, records: [ArchiveInputRecord]) -> ArchiveSyncBatch {
    ArchiveSyncBatch(schemaVersion: "icloud-cli.archive-sync.v1", providerId: provider, providerSchemaVersion: "\(provider).v1", sourceFingerprint: "fixture", cursor: "done", records: records, deletedIds: [], failure: nil)
}

private func searchRecord(_ id: String, _ title: String, _ timestamp: String) -> ArchiveInputRecord {
    ArchiveInputRecord(id: id, sourceModifiedAt: timestamp, fields: ["title": .string(title)])
}

private func federatedSearchFixture(_ name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("icloud-cli-search-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeFederatedMessagesDB(_ url: URL) throws {
    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [url.path, "CREATE TABLE recent_messages (messageId TEXT, chatIdentifier TEXT, sender TEXT, sentAt TEXT, isFromMe INTEGER, body TEXT); INSERT INTO recent_messages VALUES ('m1','group','sender','200',0,'secret body');"]
    try process.run(); process.waitUntilExit(); #expect(process.terminationStatus == 0)
}
