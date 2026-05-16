import Foundation

public struct CacheEnvelope: Codable, Equatable, Sendable {
    public let updatedAt: String
    public let ok: Bool
    public let error: String?
    public let data: String?
}

public struct CacheStatusEntry: Codable, Equatable, Sendable {
    public let command: String
    public let path: String
    public let updatedAt: String?
    public let ok: Bool?
    public let error: String?
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

    public init(outputDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".icloud-cli/cache")) {
        self.outputDirectory = outputDirectory
    }

    public func refresh(commands: [String]) throws -> [CacheStatusEntry] {
        try ensureCacheDirectory()
        var statuses: [CacheStatusEntry] = []
        for command in commands {
            let envelope: CacheEnvelope
            do {
                let data = try snapshot(command: command)
                envelope = CacheEnvelope(updatedAt: now(), ok: true, error: nil, data: data)
            } catch {
                let previous = try? readEnvelope(command: command)
                envelope = CacheEnvelope(updatedAt: now(), ok: false, error: error.localizedDescription, data: previous?.data)
            }
            try write(envelope, command: command)
            statuses.append(CacheStatusEntry(command: command, path: fileURL(for: command).path, updatedAt: envelope.updatedAt, ok: envelope.ok, error: envelope.error))
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
            return CacheStatusEntry(command: command, path: url.path, updatedAt: envelope?.updatedAt, ok: envelope?.ok, error: envelope?.error)
        }
    }

    private func ensureCacheDirectory() throws {
        if !FileManager.default.fileExists(atPath: outputDirectory.path) {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: outputDirectory.path)
    }

    private func snapshot(command: String) throws -> String {
        switch command {
        case "safari-tabs":
            return try json(SafariTabsReader().readTabs())
        case "drive-list":
            return try json(ICloudDriveInventoryReader().listFiles())
        case "photos-screenshots":
            return try json(PhotosInventoryReader().listScreenshots())
        case "storage-status":
            return try json(ICloudStorageStatusReader().readStatus())
        default:
            throw CacheWatchError.missingCommand(command)
        }
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

    private func json<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try JSONEncoder.pretty.encode(value), as: UTF8.self)
    }

    private func now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
