import Foundation
import Testing
@testable import ICloudCLICore

@Test func archiveSyncPersistsCursorAndResumesIdempotently() throws {
    let root = try archiveTestDirectory(named: "resume")
    defer { try? FileManager.default.removeItem(at: root) }
    let clock = ArchiveTestClock(date: ISO8601DateFormatter().date(from: "2026-07-12T10:00:00Z")!)
    let store = ProviderArchiveStore(rootDirectory: root, now: { clock.date }, monotonic: { 0 })
    let batch = archiveBatch(records: [archiveRecord("one", title: "First")], cursor: "cursor-1")

    let first = try store.sync(batch, budget: CrawlBudget(scanLimit: 10, wallClockLimitMilliseconds: 1_000))
    let restarted = ProviderArchiveStore(rootDirectory: root, now: { clock.date }, monotonic: { 0 })
    let second = try restarted.sync(batch, budget: CrawlBudget(scanLimit: 10, wallClockLimitMilliseconds: 1_000))
    let status = try restarted.status(providerId: "drive")

    #expect(first.upsertedCount == 1)
    #expect(second.upsertedCount == 0)
    #expect(status.cursor == "cursor-1")
    #expect(status.sourceFingerprint == "source-v1")
    #expect(status.activeItemCount == 1)
    #expect(status.lastAttemptAt == "2026-07-12T10:00:00Z")
    #expect(status.lastSuccessAt == "2026-07-12T10:00:00Z")
}

@Test func archiveSyncHandlesExplicitTombstones() throws {
    let root = try archiveTestDirectory(named: "tombstone")
    defer { try? FileManager.default.removeItem(at: root) }
    let clock = ArchiveTestClock(date: Date(timeIntervalSince1970: 1_000))
    let store = ProviderArchiveStore(rootDirectory: root, now: { clock.date }, monotonic: { 0 })
    _ = try store.sync(archiveBatch(records: [archiveRecord("one", title: "First")]), budget: .defaultPolling)
    clock.date = Date(timeIntervalSince1970: 2_000)

    let result = try store.sync(archiveBatch(records: [], deletedIds: ["one"], cursor: "cursor-2"), budget: .defaultPolling)
    let document = try store.read(providerId: "drive")

    #expect(result.tombstonedCount == 1)
    #expect(document.records.count == 1)
    #expect(document.records[0].fields == nil)
    #expect(document.records[0].tombstonedAt != nil)
    #expect(document.activeItemCount == 0)
    #expect(document.tombstoneCount == 1)
    #expect(try store.status(providerId: "drive").activeItemCount == 0)
}

@Test func archivePartialFailurePreservesLastSuccessAndCursor() throws {
    let root = try archiveTestDirectory(named: "partial")
    defer { try? FileManager.default.removeItem(at: root) }
    let clock = ArchiveTestClock(date: Date(timeIntervalSince1970: 1_000))
    let store = ProviderArchiveStore(rootDirectory: root, now: { clock.date }, monotonic: { 0 })
    _ = try store.sync(archiveBatch(records: [archiveRecord("one", title: "First")], cursor: "good"), budget: .defaultPolling)
    clock.date = Date(timeIntervalSince1970: 2_000)
    let failed = archiveBatch(records: [archiveRecord("two", title: "Second")], cursor: "unsafe", failure: ArchiveFailure(code: "source-timeout", guidance: "Retry with a narrower source scope."))

    let result = try store.sync(failed, budget: .defaultPolling)
    let status = try store.status(providerId: "drive")

    #expect(result.state == .partial)
    #expect(status.cursor == "good")
    #expect(status.lastSuccessAt == ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 1_000)))
    #expect(status.lastAttemptAt == ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 2_000)))
    #expect(status.failure?.code == "source-timeout")
    #expect(status.failure?.guidance != "Retry with a narrower source scope.")
}

@Test func archiveRetentionPurgesExpiredTombstones() throws {
    let root = try archiveTestDirectory(named: "retention")
    defer { try? FileManager.default.removeItem(at: root) }
    let clock = ArchiveTestClock(date: Date(timeIntervalSince1970: 1_000))
    let store = ProviderArchiveStore(rootDirectory: root, retention: ArchiveRetentionPolicy(tombstoneLifetimeSeconds: 100, maximumRecords: 100), now: { clock.date }, monotonic: { 0 })
    _ = try store.sync(archiveBatch(records: [archiveRecord("one", title: "First")]), budget: .defaultPolling)
    _ = try store.sync(archiveBatch(records: [], deletedIds: ["one"]), budget: .defaultPolling)
    clock.date = Date(timeIntervalSince1970: 1_200)

    _ = try store.sync(archiveBatch(records: [archiveRecord("two", title: "Second")]), budget: .defaultPolling)

    #expect(try store.read(providerId: "drive").records.map(\.id) == ["two"])
}

@Test func archiveMigratesV0Documents() throws {
    let root = try archiveTestDirectory(named: "migration")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let legacy = """
    {"schemaVersion":"icloud-cli.archive.v0","providerId":"drive","providerSchemaVersion":"drive.v0","cursor":"legacy","sourceFingerprint":"old","updatedAt":"2026-01-01T00:00:00Z","records":[]}
    """
    try Data(legacy.utf8).write(to: root.appendingPathComponent("drive.json"))
    let store = ProviderArchiveStore(rootDirectory: root)

    let document = try store.read(providerId: "drive")

    #expect(document.schemaVersion == "icloud-cli.archive.v1")
    #expect(document.cursor == "legacy")
    #expect(try String(contentsOf: root.appendingPathComponent("drive.json"), encoding: .utf8).contains("icloud-cli.archive.v1"))
}

@Test func archiveStorageUsesPrivatePermissions() throws {
    let root = try archiveTestDirectory(named: "permissions")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = ProviderArchiveStore(rootDirectory: root)
    _ = try store.sync(archiveBatch(records: [archiveRecord("one", title: "First")]), budget: .defaultPolling)

    let directoryMode = try #require((try FileManager.default.attributesOfItem(atPath: root.path)[.posixPermissions] as? NSNumber)?.intValue)
    let fileMode = try #require((try FileManager.default.attributesOfItem(atPath: root.appendingPathComponent("drive.json").path)[.posixPermissions] as? NSNumber)?.intValue)
    #expect(directoryMode & 0o777 == 0o700)
    #expect(fileMode & 0o777 == 0o600)
}

@Test func archiveRejectsHighSensitivityProvidersWithoutOptIn() throws {
    let root = try archiveTestDirectory(named: "sensitive")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = ProviderArchiveStore(rootDirectory: root)
    let batch = ArchiveSyncBatch(schemaVersion: "icloud-cli.archive-sync.v1", providerId: "messages", providerSchemaVersion: "messages.v1", sourceFingerprint: "source", cursor: nil, records: [], deletedIds: [], failure: nil)

    #expect(throws: ProviderArchiveError.providerNotArchivable("messages")) {
        try store.sync(batch, budget: .defaultPolling)
    }
}

@Test func archiveRejectsNestedSensitiveFieldsWithoutEmbeddingJSONStrings() throws {
    let root = try archiveTestDirectory(named: "nested-sensitive")
    defer { try? FileManager.default.removeItem(at: root) }
    let record = ArchiveInputRecord(id: "one", sourceModifiedAt: nil, fields: [
        "metadata": .object(["body": .string("private")]),
    ])

    #expect(throws: ProviderArchiveError.sensitiveField("body")) {
        try ProviderArchiveStore(rootDirectory: root).sync(archiveBatch(records: [record]), budget: .defaultPolling)
    }
}

@Test func archiveRejectsSensitiveFieldNestedInsideArrays() throws {
    let root = try archiveTestDirectory(named: "nested-array-sensitive")
    defer { try? FileManager.default.removeItem(at: root) }
    let record = ArchiveInputRecord(id: "one", sourceModifiedAt: nil, fields: [
        "nested": .array([.array([.object(["body": .string("private")])])]),
    ])

    #expect(throws: ProviderArchiveError.sensitiveField("body")) {
        try ProviderArchiveStore(rootDirectory: root).sync(archiveBatch(records: [record]), budget: .defaultPolling)
    }
}
@Test func archiveSyncReturnsPartialAtExplicitScanBudget() throws {
    let root = try archiveTestDirectory(named: "bounded")
    defer { try? FileManager.default.removeItem(at: root) }
    let store = ProviderArchiveStore(rootDirectory: root, monotonic: { 0 })
    let batch = archiveBatch(records: [archiveRecord("one", title: "One"), archiveRecord("two", title: "Two")], cursor: "not-safe-yet")

    let result = try store.sync(batch, budget: CrawlBudget(scanLimit: 1, wallClockLimitMilliseconds: 1_000))

    #expect(result.state == .partial)
    #expect(result.scannedCount == 1)
    #expect(result.status.cursor == nil)
    #expect(result.status.failure?.code == "scan-limit")
}

@Test func archiveSyncReturnsPartialAtExplicitTimeout() throws {
    let root = try archiveTestDirectory(named: "timeout")
    defer { try? FileManager.default.removeItem(at: root) }
    let clock = ArchiveMonotonicClock(values: [0, 0, 0.1, 0.1])
    let store = ProviderArchiveStore(rootDirectory: root, monotonic: { clock.next() })
    let batch = archiveBatch(records: [archiveRecord("one", title: "One"), archiveRecord("two", title: "Two")])

    let result = try store.sync(batch, budget: CrawlBudget(scanLimit: 10, wallClockLimitMilliseconds: 50))

    #expect(result.state == .partial)
    #expect(result.status.failure?.code == "timeout")
    #expect(result.status.cursor == nil)
}

@Test func parsesAndRunsArchiveSyncAndStatusCommands() throws {
    let root = try archiveTestDirectory(named: "commands")
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let input = root.appendingPathComponent("batch.json")
    try JSONEncoder().encode(archiveBatch(records: [archiveRecord("one", title: "One")])).write(to: input)
    let archiveDirectory = root.appendingPathComponent("archives")

    let parsed = try CLIParser().parse(arguments: ["icloud-cli", "archive", "sync", "drive", "--input", input.path, "--archive-dir", archiveDirectory.path, "--scan-limit", "10", "--timeout-ms", "500"])
    guard case .archiveSync(let options) = parsed else { Issue.record("Expected archive sync"); return }
    #expect(options.providerId == "drive")
    #expect(options.budget == CrawlBudget(scanLimit: 10, wallClockLimitMilliseconds: 500))

    final class Sink: @unchecked Sendable { var output: [String] = []; var errors: [String] = [] }
    let sink = Sink()
    let runner = CommandRunner(output: { sink.output.append($0) }, errorOutput: { sink.errors.append($0) })
    #expect(runner.run(arguments: ["icloud-cli", "archive", "sync", "drive", "--input", input.path, "--archive-dir", archiveDirectory.path]) == 0)
    #expect(runner.run(arguments: ["icloud-cli", "archive", "status", "drive", "--archive-dir", archiveDirectory.path]) == 0)
    #expect(sink.errors.isEmpty)
    #expect(try JSONDecoder().decode(ArchiveSyncResult.self, from: Data(sink.output[0].utf8)).status.activeItemCount == 1)
    #expect(try JSONDecoder().decode(ArchiveProviderStatus.self, from: Data(sink.output[1].utf8)).providerId == "drive")
}

private final class ArchiveTestClock: @unchecked Sendable {
    var date: Date
    init(date: Date) { self.date = date }
}

private final class ArchiveMonotonicClock: @unchecked Sendable {
    private var values: [TimeInterval]
    private let lock = NSLock()
    init(values: [TimeInterval]) { self.values = values }
    func next() -> TimeInterval {
        lock.lock(); defer { lock.unlock() }
        if values.count > 1 { return values.removeFirst() }
        return values.first ?? 0
    }
}

private func archiveBatch(records: [ArchiveInputRecord], deletedIds: [String] = [], cursor: String = "cursor", failure: ArchiveFailure? = nil) -> ArchiveSyncBatch {
    ArchiveSyncBatch(schemaVersion: "icloud-cli.archive-sync.v1", providerId: "drive", providerSchemaVersion: "drive.metadata.v1", sourceFingerprint: "source-v1", cursor: cursor, records: records, deletedIds: deletedIds, failure: failure)
}

private func archiveRecord(_ id: String, title: String) -> ArchiveInputRecord {
    ArchiveInputRecord(id: id, sourceModifiedAt: "2026-07-12T09:00:00Z", fields: ["title": .string(title)])
}

private func archiveTestDirectory(named name: String) throws -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("icloud-cli-archive-\(name)-\(UUID().uuidString)")
}
