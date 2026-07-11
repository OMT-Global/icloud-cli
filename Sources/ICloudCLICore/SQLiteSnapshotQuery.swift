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
            try copy(source, to: snapshot)
            for suffix in ["-wal", "-shm"] {
                let companion = URL(fileURLWithPath: source.path + suffix)
                guard FileManager.default.fileExists(atPath: companion.path) else { continue }
                try copy(companion, to: URL(fileURLWithPath: snapshot.path + suffix))
            }
        } catch {
            if isPermissionError(error) { throw LocalInventoryError.permissionDenied(reportedStore) }
            throw LocalInventoryError.sqliteFailure("Unable to create SQLite snapshot")
        }
        return try operation(snapshot, directory)
    }

    private func copy(_ source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
    }

    private func isPermissionError(_ error: Error) -> Bool {
        let cocoa = error as NSError
        return cocoa.domain == NSCocoaErrorDomain && [NSFileReadNoPermissionError, NSFileWriteNoPermissionError].contains(cocoa.code)
    }
}
