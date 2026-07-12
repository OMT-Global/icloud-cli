import Foundation

public struct CacheEnvelope: Codable, Equatable, Sendable {
    public let updatedAt: String
    public let ok: Bool
    public let error: String?
    public let data: String?
    public let failure: CacheFailure?
}

public struct CacheFailure: Codable, Equatable, Sendable {
    public let code: String
    public let providerId: String
    public let guidance: String
}

public struct CacheStatusEntry: Codable, Equatable, Sendable {
    public let command: String
    public let path: String
    public let updatedAt: String?
    public let ok: Bool?
    public let error: String?
    public let failure: CacheFailure?
}

public enum CacheWatchError: Error, LocalizedError, Equatable {
    case missingCommand(String)
    case missingCacheFile(String)

    public var errorDescription: String? {
        switch self {
        case .missingCommand(let command): return "Unsupported cache command: \(command)"
        case .missingCacheFile(let command): return "No cached output found for \(command)"
        }
    }
}

public struct CacheWatchStore: Sendable {
    public static let defaultCommands = ["safari-tabs", "drive-list", "photos-screenshots", "storage-status"]

    public let outputDirectory: URL
    private let snapshotter: CacheSnapshotter

    public init(outputDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".icloud-cli/cache")) {
        self.outputDirectory = outputDirectory
        self.snapshotter = Self.defaultSnapshot
    }

    init(outputDirectory: URL, snapshotter: @escaping CacheSnapshotter) {
        self.outputDirectory = outputDirectory
        self.snapshotter = snapshotter
    }

    public func refresh(commands: [String], budget: CrawlBudget = .defaultPolling) throws -> [CacheStatusEntry] {
        try ensureCacheDirectory()
        var statuses: [CacheStatusEntry] = []
        for command in commands {
            let envelope: CacheEnvelope
            do {
                let data = try snapshotter(command, budget)
                envelope = CacheEnvelope(updatedAt: now(), ok: true, error: nil, data: data, failure: nil)
            } catch {
                let previous = try? readEnvelope(command: command)
                let failure = redactedFailure(error, command: command)
                envelope = CacheEnvelope(updatedAt: now(), ok: false, error: failure.message, data: previous?.data, failure: failure.detail)
            }
            try write(envelope, command: command)
            statuses.append(CacheStatusEntry(command: command, path: fileURL(for: command).path, updatedAt: envelope.updatedAt, ok: envelope.ok, error: envelope.error, failure: envelope.failure))
        }
        return statuses
    }

    public func read(command: String) throws -> CacheEnvelope {
        try readEnvelope(command: command)
    }

    public func status() throws -> [CacheStatusEntry] {
        guard FileManager.default.fileExists(atPath: outputDirectory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: outputDirectory, includingPropertiesForKeys: nil)
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { url in
            let command = url.deletingPathExtension().lastPathComponent
            let envelope = try? readEnvelope(command: command)
            return CacheStatusEntry(command: command, path: url.path, updatedAt: envelope?.updatedAt, ok: envelope?.ok, error: envelope?.error, failure: envelope?.failure)
        }
    }

    private func ensureCacheDirectory() throws {
        if !FileManager.default.fileExists(atPath: outputDirectory.path) {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: outputDirectory.path)
    }

    private static func defaultSnapshot(command: String, budget: CrawlBudget) throws -> String {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let data: String
        switch command {
        case "safari-tabs":
            data = try json(SafariTabsReader().readTabs())
        case "drive-list":
            let report = try ICloudDriveInventoryReader().listFilesReport(budget: budget)
            guard report.state == .complete else { throw CrawlBudgetExceeded(providerId: "drive", state: report.state) }
            data = try json(report)
        case "photos-screenshots":
            data = try json(PhotosInventoryReader().listScreenshots())
        case "storage-status":
            data = try json(ICloudStorageStatusReader().readStatus())
        default:
            throw CacheWatchError.missingCommand(command)
        }
        let elapsed = Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
        guard elapsed < budget.wallClockLimitMilliseconds else {
            throw CrawlBudgetExceeded(providerId: command.split(separator: "-").first.map(String.init) ?? "unknown", state: .timeout)
        }
        return data
    }

    private func redactedFailure(_ error: Error, command: String) -> (message: String, detail: CacheFailure) {
        let providerId = command.split(separator: "-").first.map(String.init) ?? "unknown"
        if let exceeded = error as? CrawlBudgetExceeded {
            let code = exceeded.state == .timeout ? "timeout" : "partial"
            let message = exceeded.state == .timeout ? "provider crawl timed out" : "provider crawl reached its scan budget"
            return (message, CacheFailure(code: code, providerId: exceeded.providerId, guidance: "Narrow the provider scope or increase its explicit crawl budget."))
        }
        return ("provider crawl failed", CacheFailure(code: "provider-error", providerId: providerId, guidance: "Run the provider directly for local diagnostic details."))
    }

    private func write(_ envelope: CacheEnvelope, command: String) throws {
        let data = try JSONEncoder.pretty.encode(envelope)
        let target = fileURL(for: command)
        let temp = outputDirectory.appendingPathComponent(".\(target.lastPathComponent).tmp")
        try data.write(to: temp, options: [.atomic])
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.moveItem(at: temp, to: target)
    }

    private func readEnvelope(command: String) throws -> CacheEnvelope {
        let url = fileURL(for: command)
        guard FileManager.default.fileExists(atPath: url.path) else { throw CacheWatchError.missingCacheFile(command) }
        return try JSONDecoder().decode(CacheEnvelope.self, from: Data(contentsOf: url))
    }

    private func fileURL(for command: String) -> URL {
        outputDirectory.appendingPathComponent(command).appendingPathExtension("json")
    }

    private static func json<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder.pretty.encode(value), as: UTF8.self)
    }

    private func now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

typealias CacheSnapshotter = @Sendable (String, CrawlBudget) throws -> String

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
