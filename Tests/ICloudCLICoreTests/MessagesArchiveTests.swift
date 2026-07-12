import Foundation
import Testing
@testable import ICloudCLICore

@Test func messagesArchiveIsIncrementalDeduplicatedAndPreservesGroupChats() throws {
    let root = try messagesArchiveFixture("incremental")
    defer { try? FileManager.default.removeItem(at: root) }
    let database = root.appendingPathComponent("chat.db")
    try makeMessagesArchiveDatabase(database)
    let archive = root.appendingPathComponent("archive")
    let adapter = MessagesArchiveAdapter(archiveDirectory: archive)

    let first = try adapter.sync(database: database, includeBodies: false, bodyRetentionDays: nil, limit: 100)
    let second = try adapter.sync(database: database, includeBodies: false, bodyRetentionDays: nil, limit: 100)

    #expect(first.status.activeItemCount == 2)
    #expect(second.upsertedCount == 0)
    #expect(second.status.cursor == "200")
    let hits = try adapter.search(query: "group", includeBodies: false, limit: 10)
    #expect(hits.map(\.chatIdentifier) == ["chat-group"])
    #expect(hits.first?.body == nil)

    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3"); process.arguments = [database.path, "DELETE FROM recent_messages WHERE messageId='m1';"]
    try process.run(); process.waitUntilExit()
    let deleted = try adapter.sync(database: database, includeBodies: false, bodyRetentionDays: nil, limit: 100)
    #expect(deleted.tombstonedCount == 1)
}

@Test func messagesArchiveBodiesRequireExplicitRetentionAndSearchConfirmation() throws {
    let root = try messagesArchiveFixture("bodies")
    defer { try? FileManager.default.removeItem(at: root) }
    let database = root.appendingPathComponent("chat.db")
    try makeMessagesArchiveDatabase(database)
    let adapter = MessagesArchiveAdapter(archiveDirectory: root.appendingPathComponent("archive"))

    #expect(throws: MessagesArchiveError.bodyRetentionRequired) {
        try adapter.sync(database: database, includeBodies: true, bodyRetentionDays: nil, limit: 10)
    }
    _ = try adapter.sync(database: database, includeBodies: true, bodyRetentionDays: 7, limit: 10)
    #expect(throws: MessagesArchiveError.sensitiveConfirmationRequired) {
        try adapter.search(query: "secret", includeBodies: true, confirmSensitive: false, limit: 10)
    }
    #expect(try adapter.search(query: "secret", includeBodies: true, confirmSensitive: true, limit: 10).count == 1)

    let future = MessagesArchiveAdapter(archiveDirectory: root.appendingPathComponent("archive"), now: { Date(timeIntervalSinceNow: 8 * 86_400) })
    _ = try future.sync(database: database, includeBodies: true, bodyRetentionDays: 7, limit: 10)
    #expect(try future.search(query: "secret", includeBodies: true, confirmSensitive: true, limit: 10).isEmpty)
}

@Test func parsesMessagesArchiveAndSearchCommands() throws {
    let archive = try CLIParser().parse(arguments: ["icloud-cli", "messages", "archive", "--confirm-sensitive", "--include-body", "--body-retention-days", "7", "--limit", "50"])
    guard case .messagesArchive(let options) = archive else { Issue.record("Expected messages archive"); return }
    #expect(options.confirmSensitive && options.includeBody && options.bodyRetentionDays == 7 && options.limit == 50)

    let search = try CLIParser().parse(arguments: ["icloud-cli", "messages", "search", "group", "--limit", "5"])
    guard case .messagesSearch(let options) = search else { Issue.record("Expected messages search"); return }
    #expect(options.query == "group" && options.limit == 5)
}

@Test func externalArchiveBatchCannotSelfAuthorizeMessageBodies() throws {
    let data = Data("""
    {"schemaVersion":"icloud-cli.archive-sync.v1","providerId":"messages","providerSchemaVersion":"messages.v1","sourceFingerprint":"source","records":[{"id":"m1","fields":{"body":"secret"}}],"deletedIds":[],"sensitiveFields":["body"]}
    """.utf8)
    let batch = try JSONDecoder().decode(ArchiveSyncBatch.self, from: data)
    #expect(batch.sensitiveFields == nil)
    let root = try messagesArchiveFixture("untrusted-batch")
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(throws: ProviderArchiveError.sensitiveField("body")) {
        try ProviderArchiveStore(rootDirectory: root).sync(batch, budget: .defaultPolling)
    }
}

private func messagesArchiveFixture(_ name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("icloud-cli-messages-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeMessagesArchiveDatabase(_ url: URL) throws {
    let sql = """
    CREATE TABLE recent_messages (messageId TEXT, chatIdentifier TEXT, sender TEXT, sentAt TEXT, isFromMe INTEGER, body TEXT);
    INSERT INTO recent_messages VALUES ('m1', 'chat-direct', '+15550001', '100', 0, 'ordinary');
    INSERT INTO recent_messages VALUES ('m2', 'chat-group', '+15550002', '200', 1, 'group secret');
    """
    let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3"); process.arguments = [url.path, sql]
    try process.run(); process.waitUntilExit()
    #expect(process.terminationStatus == 0)
}
