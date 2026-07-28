import Foundation
import Testing
@testable import ICloudCLICore

private struct SnapshotValueRow: Decodable, Equatable { let value: String }

@Test func productionSnapshotEngineEnforcesTimeoutFloors() {
    let source = URL(fileURLWithPath: "/private/source.db")
    let constrained = SQLiteSnapshotQueryEngine.production(
        source: source,
        timeout: 0.001,
        busyTimeoutMilliseconds: 0
    )
    let relaxed = SQLiteSnapshotQueryEngine.production(
        source: source,
        timeout: 7,
        busyTimeoutMilliseconds: 800
    )

    #expect(constrained.timeout == 5)
    #expect(constrained.busyTimeoutMilliseconds == 500)
    #expect(relaxed.timeout == 7)
    #expect(relaxed.busyTimeoutMilliseconds == 800)
}

@Test func snapshotQueryReadsDatabaseWithoutCompanionFilesAndCleansUp() throws {
    let root = try temporarySQLiteSnapshotDirectory(named: "no-companions")
    defer { try? FileManager.default.removeItem(at: root) }
    let database = root.appendingPathComponent("source.db")
    try runSnapshotFixtureSQL(database: database, sql: "CREATE TABLE values_table (value TEXT); INSERT INTO values_table VALUES ('one');")
    let snapshots = root.appendingPathComponent("snapshots")
    try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)

    let rows: [SnapshotValueRow] = try SQLiteSnapshotQueryEngine(source: database, temporaryRoot: snapshots)
        .query("SELECT value FROM values_table;")

    #expect(rows == [SnapshotValueRow(value: "one")])
    #expect(try FileManager.default.contentsOfDirectory(atPath: snapshots.path).isEmpty)
}

@Test func snapshotQueryIncludesCommittedWALRows() throws {
    let root = try temporarySQLiteSnapshotDirectory(named: "wal")
    defer { try? FileManager.default.removeItem(at: root) }
    let database = root.appendingPathComponent("source.db")
    let writer = try openWALFixture(database: database)
    defer { writer.stop() }

    #expect(FileManager.default.fileExists(atPath: database.path + "-wal"))
    let rows: [SnapshotValueRow] = try SQLiteSnapshotQueryEngine(source: database)
        .query("SELECT value FROM values_table ORDER BY value;")
    #expect(rows == [SnapshotValueRow(value: "wal-row")])
}

@Test func snapshotQueryFollowsSymlinkedStoreWithCoherentWALSnapshot() throws {
    let root = try temporarySQLiteSnapshotDirectory(named: "symlink-wal")
    defer { try? FileManager.default.removeItem(at: root) }
    let liveStore = root.appendingPathComponent("live/source.db")
    try FileManager.default.createDirectory(at: liveStore.deletingLastPathComponent(), withIntermediateDirectories: true)
    let writer = try openWALFixture(database: liveStore)
    defer { writer.stop() }
    let linkedStore = root.appendingPathComponent("linked-source.db")
    try FileManager.default.createSymbolicLink(atPath: linkedStore.path, withDestinationPath: liveStore.path)

    let engine = SQLiteSnapshotQueryEngine(source: linkedStore)
    try engine.withSnapshot { snapshot, workspace in
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: snapshot.path)) == nil)
        #expect(!FileManager.default.fileExists(atPath: snapshot.path + "-wal"))
        let rows: [SnapshotValueRow] = try engine.querySnapshot(snapshot, workspace: workspace, sql: "SELECT value FROM values_table ORDER BY value;")
        #expect(rows == [SnapshotValueRow(value: "wal-row")])
    }
}

@Test func snapshotQueryCreatesSingleFileSnapshotForLiveWALStore() throws {
    let root = try temporarySQLiteSnapshotDirectory(named: "coherent-wal")
    defer { try? FileManager.default.removeItem(at: root) }
    let database = root.appendingPathComponent("source.db")
    let writer = try openWALFixture(database: database)
    defer { writer.stop() }
    let engine = SQLiteSnapshotQueryEngine(source: database)

    try engine.withSnapshot { snapshot, workspace in
        #expect(!FileManager.default.fileExists(atPath: snapshot.path + "-wal"))
        let rows: [SnapshotValueRow] = try engine.querySnapshot(snapshot, workspace: workspace, sql: "SELECT value FROM values_table;")
        #expect(rows == [SnapshotValueRow(value: "wal-row")])
    }
}

@Test func snapshotQueryMapsSchemaDriftAndBusyFailures() {
    let schema = sqliteError(from: Data("Error: no such table: missing".utf8), store: "/private/source.db")
    #expect(schema == .unsupportedSchema(store: "/private/source.db", detail: "Error: no such table: missing"))

    let locked = sqliteError(from: Data("Error: database is locked".utf8), store: "/private/source.db")
    #expect(locked == .lockedStore("/private/source.db"))
}

@Test func snapshotQueryRejectsWritesAndLeavesSourceUnchanged() throws {
    let root = try temporarySQLiteSnapshotDirectory(named: "query-only")
    defer { try? FileManager.default.removeItem(at: root) }
    let database = root.appendingPathComponent("source.db")
    try runSnapshotFixtureSQL(database: database, sql: "CREATE TABLE values_table (value TEXT); INSERT INTO values_table VALUES ('one');")
    let engine = SQLiteSnapshotQueryEngine(source: database)

    #expect(throws: LocalInventoryError.self) {
        let _: [SnapshotValueRow] = try engine.query("INSERT INTO values_table VALUES ('two') RETURNING value;")
    }
    #expect(try snapshotFixtureScalar(database: database, sql: "SELECT COUNT(*) FROM values_table;") == "1")
}

@Test func snapshotQueryReportsLockedStore() throws {
    let root = try temporarySQLiteSnapshotDirectory(named: "locked")
    defer { try? FileManager.default.removeItem(at: root) }
    let database = root.appendingPathComponent("source.db")
    try runSnapshotFixtureSQL(database: database, sql: "CREATE TABLE values_table (value TEXT); INSERT INTO values_table VALUES ('one');")
    let engine = SQLiteSnapshotQueryEngine(source: database, busyTimeoutMilliseconds: 20)

    #expect(throws: LocalInventoryError.lockedStore(database.path)) {
        try engine.withSnapshot { snapshot, workspace in
            let locker = try lockSnapshotDatabase(snapshot)
            defer { locker.stop() }
            Thread.sleep(forTimeInterval: 0.05)
            let _: [SnapshotValueRow] = try engine.querySnapshot(snapshot, workspace: workspace, sql: "SELECT value FROM values_table;")
        }
    }
}

@Test func snapshotQueryTimesOutAndCleansUp() throws {
    let root = try temporarySQLiteSnapshotDirectory(named: "timeout")
    defer { try? FileManager.default.removeItem(at: root) }
    let database = root.appendingPathComponent("source.db")
    try runSnapshotFixtureSQL(database: database, sql: "CREATE TABLE values_table (value TEXT);")
    let snapshots = root.appendingPathComponent("snapshots")
    try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
    let engine = SQLiteSnapshotQueryEngine(source: database, timeout: 0.01, temporaryRoot: snapshots)

    #expect(throws: LocalInventoryError.queryTimeout(database.path)) {
        let _: [SnapshotValueRow] = try engine.query("WITH RECURSIVE loop(x) AS (VALUES(0) UNION ALL SELECT x + 1 FROM loop LIMIT 100000000) SELECT CAST(MAX(x) AS TEXT) AS value FROM loop;")
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: snapshots.path).isEmpty)
}

@Test func snapshotQueryMapsCopyPermissionFailures() throws {
    let root = try temporarySQLiteSnapshotDirectory(named: "permission")
    defer { try? FileManager.default.removeItem(at: root) }
    let database = root.appendingPathComponent("source.db")
    try runSnapshotFixtureSQL(database: database, sql: "CREATE TABLE values_table (value TEXT);")
    try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: database.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: database.path) }

    #expect(throws: LocalInventoryError.permissionDenied(database.path)) {
        let _: [SnapshotValueRow] = try SQLiteSnapshotQueryEngine(source: database).query("SELECT value FROM values_table;")
    }
}

private final class WALFixtureWriter {
    let process: Process
    let input: FileHandle

    init(process: Process, input: FileHandle) { self.process = process; self.input = input }

    func stop() {
        try? input.write(contentsOf: Data(".quit\n".utf8))
        try? input.close()
        process.waitUntilExit()
    }
}

private func openWALFixture(database: URL) throws -> WALFixtureWriter {
    let process = Process()
    let input = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [database.path]
    process.standardInput = input
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    let commands = "PRAGMA journal_mode=WAL; PRAGMA wal_autocheckpoint=0; CREATE TABLE values_table (value TEXT); INSERT INTO values_table VALUES ('wal-row');\n"
    try input.fileHandleForWriting.write(contentsOf: Data(commands.utf8))

    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline {
        if FileManager.default.fileExists(atPath: database.path + "-wal"),
           (try? snapshotFixtureScalar(database: database, sql: "SELECT value FROM values_table;")) == "wal-row" {
            break
        }
        Thread.sleep(forTimeInterval: 0.01)
    }
    return WALFixtureWriter(process: process, input: input.fileHandleForWriting)
}

private func lockSnapshotDatabase(_ database: URL) throws -> WALFixtureWriter {
    let process = Process()
    let input = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [database.path]
    process.standardInput = input
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    try input.fileHandleForWriting.write(contentsOf: Data("PRAGMA locking_mode=EXCLUSIVE; BEGIN EXCLUSIVE; SELECT 1;\n".utf8))
    return WALFixtureWriter(process: process, input: input.fileHandleForWriting)
}

private func snapshotFixtureScalar(database: URL, sql: String) throws -> String {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = ["-readonly", database.path, sql]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw CocoaError(.fileReadUnknown) }
    return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func temporarySQLiteSnapshotDirectory(named name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("icloud-cli-snapshot-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func runSnapshotFixtureSQL(database: URL, sql: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [database.path, sql]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
}
