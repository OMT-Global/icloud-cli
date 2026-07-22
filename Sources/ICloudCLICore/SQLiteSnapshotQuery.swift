import Darwin
import Foundation

public struct SQLiteSnapshotQueryEngine: Sendable {
    public let source: URL
    public let timeout: TimeInterval
    public let busyTimeoutMilliseconds: Int
    public let temporaryRoot: URL
    private let reportedStore: String

    public init(
        source: URL,
        timeout: TimeInterval = 10,
        busyTimeoutMilliseconds: Int = 1_000,
        temporaryRoot: URL = FileManager.default.temporaryDirectory,
        reportedStore: String? = nil
    ) {
        self.source = source
        self.timeout = max(0.001, timeout)
        self.busyTimeoutMilliseconds = max(0, busyTimeoutMilliseconds)
        self.temporaryRoot = temporaryRoot
        self.reportedStore = reportedStore ?? source.path
    }

    public func query<T: Decodable>(_ sql: String) throws -> [T] {
        try withSnapshot { snapshot, directory in
            try querySnapshot(snapshot, workspace: directory, sql: sql)
        }
    }

    func querySnapshot<T: Decodable>(_ snapshot: URL, workspace: URL, sql: String) throws -> [T] {
        let identifier = UUID().uuidString
        let output = workspace.appendingPathComponent("query-\(identifier).json")
        let errors = workspace.appendingPathComponent("query-\(identifier).err")
        FileManager.default.createFile(atPath: output.path, contents: nil, attributes: [.posixPermissions: 0o600])
        FileManager.default.createFile(atPath: errors.path, contents: nil, attributes: [.posixPermissions: 0o600])
        defer {
            try? FileManager.default.removeItem(at: output)
            try? FileManager.default.removeItem(at: errors)
        }
        let outputHandle = try FileHandle(forWritingTo: output)
        let errorHandle = try FileHandle(forWritingTo: errors)
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-readonly", "-json",
            "-cmd", ".timeout \(busyTimeoutMilliseconds)",
            "-cmd", "PRAGMA query_only=ON;",
            snapshot.path,
            sql,
        ]
        process.standardOutput = outputHandle
        process.standardError = errorHandle

        let completed = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completed.signal() }
        do {
            try process.run()
        } catch {
            throw LocalInventoryError.sqliteFailure(error.localizedDescription)
        }
        guard completed.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            if completed.wait(timeout: .now() + 1) != .success {
                Darwin.kill(process.processIdentifier, SIGKILL)
                _ = completed.wait(timeout: .now() + 1)
            }
            throw LocalInventoryError.queryTimeout(reportedStore)
        }

        outputHandle.synchronizeFile()
        errorHandle.synchronizeFile()
        let data = try Data(contentsOf: output)
        let errorData = try Data(contentsOf: errors)
        guard process.terminationStatus == 0 else {
            throw sqliteError(from: errorData, store: reportedStore)
        }
        if data.isEmpty { return [] }
        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            throw LocalInventoryError.sqliteFailure("SQLite returned an invalid JSON result")
        }
    }

    func withSnapshot<Result>(_ operation: (URL, URL) throws -> Result) throws -> Result {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw LocalInventoryError.missingStore(reportedStore)
        }

        let directory = temporaryRoot.appendingPathComponent("icloud-cli-sqlite-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw LocalInventoryError.sqliteFailure("Unable to create private SQLite snapshot directory")
        }
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshot = directory.appendingPathComponent("snapshot.sqlite")
        do {
            try createSQLiteSnapshot(from: source, to: snapshot)
        } catch let error as LocalInventoryError {
            throw error
        } catch {
            throw LocalInventoryError.sqliteFailure("Unable to create SQLite snapshot")
        }
        return try operation(snapshot, directory)
    }

    private func createSQLiteSnapshot(from source: URL, to destination: URL) throws {
        let process = Process()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-cmd", ".timeout \(busyTimeoutMilliseconds)",
            source.path,
            "VACUUM INTO '\(sqliteLiteral(destination.path))';",
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors

        let completed = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completed.signal() }
        do {
            try process.run()
        } catch {
            throw LocalInventoryError.sqliteFailure(error.localizedDescription)
        }
        guard completed.wait(timeout: .now() + timeout) == .success else {
            if process.isRunning { process.terminate() }
            if completed.wait(timeout: .now() + 1) != .success, process.isRunning {
                Darwin.kill(process.processIdentifier, SIGKILL)
                _ = completed.wait(timeout: .now() + 1)
            }
            throw LocalInventoryError.queryTimeout(reportedStore)
        }

        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            if String(decoding: errorData, as: UTF8.self).lowercased().contains("unable to open database") {
                throw LocalInventoryError.permissionDenied(reportedStore)
            }
            throw sqliteError(from: errorData, store: reportedStore)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }

    private func sqliteLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}
