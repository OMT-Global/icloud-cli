import Foundation

public enum DriveSortKey: String, Sendable {
    case name
    case size
    case modified
}

public enum ICloudFileStatus: String, Codable, Equatable, Sendable {
    case downloaded
    case evicted
    case notDownloaded
    case downloading
    case uploaded
    case uploading
    case error
    case unknown
}

public struct ICloudDriveFile: Codable, Equatable, Sendable {
    public let path: String
    public let name: String
    public let sizeBytes: Int64?
    public let modifiedAt: Date?
    public let iCloudStatus: ICloudFileStatus
    public let appContainer: String
}

public struct ICloudDriveContainer: Codable, Equatable, Sendable {
    public let bundleId: String
    public let displayName: String
    public let sizeBytes: Int64?
    public let modifiedAt: Date?
}

public struct ICloudDriveSyncSummary: Codable, Equatable, Sendable {
    public let downloadedCount: Int
    public let cloudOnlyCount: Int
    public let downloadingCount: Int
    public let uploadedCount: Int
    public let uploadingCount: Int
    public let errorCount: Int
    public let unknownCount: Int
}

public struct ICloudDriveErrorEntry: Codable, Equatable, Sendable {
    public let path: String
    public let category: String
}

public struct ICloudDriveSharedItem: Codable, Equatable, Sendable {
    public let path: String
    public let owner: String?
    public let role: String?
    public let dateShared: Date?
    public let iCloudStatus: ICloudFileStatus
}

public enum DriveInventoryError: Error, LocalizedError, Equatable {
    case missingRoot(String)
    case invalidPath(String)

    public var errorDescription: String? {
        switch self {
        case .missingRoot(let path): return "iCloud Drive root not available: \(path)"
        case .invalidPath(let path): return "Path is outside the iCloud Drive root: \(path)"
        }
    }
}

public struct ICloudDriveInventoryReader: Sendable {
    public let rootDirectory: URL
    public init(rootDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents")) {
        self.rootDirectory = rootDirectory.standardizedFileURL
    }

    public func listFiles(path requestedPath: String? = nil, depth: Int = 2, limit: Int? = nil) throws -> [ICloudDriveFile] {
        guard FileManager.default.fileExists(atPath: rootDirectory.path) else { throw DriveInventoryError.missingRoot(rootDirectory.path) }
        let startURL = try scopedURL(for: requestedPath)
        let startValues = try? startURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        if startValues?.isDirectory != true {
            return [fileEntry(for: startURL, values: startValues)]
        }
        let maxDepth = max(0, depth)
        let maxFiles = limit.map { max(1, $0) }
        var result: [ICloudDriveFile] = []
        try walkFiles(at: startURL, currentDepth: 0, maxDepth: maxDepth, maxFiles: maxFiles, into: &result)
        return result.sorted { lhs, rhs in lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending }
    }

    public func syncStatus(path requestedPath: String? = nil, limit: Int = 500) throws -> ICloudDriveSyncSummary {
        let files = try listFiles(path: requestedPath, depth: Int.max, limit: limit)
        return ICloudDriveSyncSummary(
            downloadedCount: files.filter { $0.iCloudStatus == .downloaded }.count,
            cloudOnlyCount: files.filter { $0.iCloudStatus == .evicted || $0.iCloudStatus == .notDownloaded }.count,
            downloadingCount: files.filter { $0.iCloudStatus == .downloading }.count,
            uploadedCount: files.filter { $0.iCloudStatus == .uploaded }.count,
            uploadingCount: files.filter { $0.iCloudStatus == .uploading }.count,
            errorCount: files.filter { $0.iCloudStatus == .error }.count,
            unknownCount: files.filter { $0.iCloudStatus == .unknown }.count
        )
    }

    public func errorFiles(path requestedPath: String? = nil, limit: Int = 500) throws -> [ICloudDriveErrorEntry] {
        try listFiles(path: requestedPath, depth: Int.max, limit: limit)
            .filter { $0.iCloudStatus == .error }
            .map { ICloudDriveErrorEntry(path: $0.path, category: "icloud-sync-error") }
    }

    public func recentFiles(since: String? = nil, limit: Int = 50) throws -> [ICloudDriveFile] {
        let floor = since.flatMap { ISO8601DateFormatter().date(from: $0) }
        let scanLimit = max(200, bounded(limit, defaultValue: 50, max: 1_000) * 5)
        return try listFiles(depth: Int.max, limit: scanLimit)
            .filter { file in
                guard let floor else { return true }
                return file.modifiedAt.map { $0 >= floor } ?? false
            }
            .sorted { ($0.modifiedAt ?? .distantPast, $0.path) > ($1.modifiedAt ?? .distantPast, $1.path) }
            .prefix(max(1, limit))
            .map { $0 }
    }

    public func sharedItems(path requestedPath: String? = nil, limit: Int = 500) throws -> [ICloudDriveSharedItem] {
        try listFiles(path: requestedPath, depth: Int.max, limit: limit)
            .filter { $0.path.localizedCaseInsensitiveContains(".shared") }
            .map { file in
                ICloudDriveSharedItem(path: file.path, owner: nil, role: nil, dateShared: file.modifiedAt, iCloudStatus: file.iCloudStatus)
            }
    }

    public func listContainers(sortBy: DriveSortKey = .name) throws -> [ICloudDriveContainer] {
        guard FileManager.default.fileExists(atPath: rootDirectory.path) else { throw DriveInventoryError.missingRoot(rootDirectory.path) }
        let children = try FileManager.default.contentsOfDirectory(at: rootDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        var containers: [ICloudDriveContainer] = []
        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let stats: (sizeBytes: Int64?, modifiedAt: Date?) = shouldComputeContainerStats(for: sortBy) ? directoryStats(child) : (nil, nil)
            containers.append(ICloudDriveContainer(bundleId: child.lastPathComponent, displayName: displayName(for: child.lastPathComponent), sizeBytes: stats.sizeBytes, modifiedAt: stats.modifiedAt))
        }
        return sort(containers, by: sortBy)
    }

    private func scopedURL(for requestedPath: String?) throws -> URL {
        guard let requestedPath, !requestedPath.isEmpty else { return rootDirectory }
        let url: URL
        if requestedPath.hasPrefix("/") { url = URL(fileURLWithPath: requestedPath) }
        else { url = rootDirectory.appendingPathComponent(requestedPath) }
        let standardized = url.standardizedFileURL
        guard standardized.path == rootDirectory.path || standardized.path.hasPrefix(rootDirectory.path + "/") else { throw DriveInventoryError.invalidPath(standardized.path) }
        return standardized
    }

    private func walkFiles(at directory: URL, currentDepth: Int, maxDepth: Int, maxFiles: Int?, into result: inout [ICloudDriveFile]) throws {
        if let maxFiles, result.count >= maxFiles {
            return
        }
        let directoryValues = try? directory.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        if directoryValues?.isDirectory != true {
            result.append(fileEntry(for: directory, values: directoryValues))
            return
        }
        let children = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey], options: [])
        for child in children {
            if let maxFiles, result.count >= maxFiles {
                return
            }
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            if values?.isDirectory == true {
                if currentDepth < maxDepth { try walkFiles(at: child, currentDepth: currentDepth + 1, maxDepth: maxDepth, maxFiles: maxFiles, into: &result) }
                continue
            }
            result.append(fileEntry(for: child, values: values))
        }
    }

    private func fileEntry(for url: URL, values: URLResourceValues?) -> ICloudDriveFile {
        let status = status(for: url)
        return ICloudDriveFile(path: relativePath(for: url), name: displayFileName(for: url), sizeBytes: status == .evicted ? nil : values?.fileSize.map(Int64.init), modifiedAt: values?.contentModificationDate, iCloudStatus: status, appContainer: appContainer(for: url))
    }

    private func status(for url: URL) -> ICloudFileStatus {
        let name = url.lastPathComponent
        if name.hasPrefix(".") && name.hasSuffix(".icloud") { return .evicted }
        if name.hasSuffix(".icloud") { return .uploading }
        return .downloaded
    }

    private func displayFileName(for url: URL) -> String {
        let name = url.lastPathComponent
        if name.hasPrefix(".") && name.hasSuffix(".icloud") {
            let start = name.index(after: name.startIndex)
            let end = name.index(name.endIndex, offsetBy: -".icloud".count)
            return String(name[start..<end])
        }
        return name
    }

    private func relativePath(for url: URL) -> String {
        let path = url.standardizedFileURL.path
        if path == rootDirectory.path { return "." }
        return String(path.dropFirst(rootDirectory.path.count + 1))
    }

    private func appContainer(for url: URL) -> String {
        let relative = relativePath(for: url)
        return relative.split(separator: "/").first.map(String.init) ?? ""
    }

    private func directoryStats(_ directory: URL) -> (sizeBytes: Int64?, modifiedAt: Date?) {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey], options: []) else { return (nil, nil) }
        var size: Int64 = 0
        var sawFile = false
        var latest: Date?
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            if let modified = values?.contentModificationDate, latest.map({ modified > $0 }) ?? true { latest = modified }
            if values?.isDirectory == true { continue }
            if status(for: url) == .evicted { continue }
            if let fileSize = values?.fileSize { size += Int64(fileSize); sawFile = true }
        }
        return (sawFile ? size : nil, latest)
    }

    private func displayName(for bundleId: String) -> String {
        bundleId.replacingOccurrences(of: "com~apple~", with: "Apple ").replacingOccurrences(of: "~", with: ".")
    }

    private func shouldComputeContainerStats(for sortBy: DriveSortKey) -> Bool {
        switch sortBy {
        case .size, .modified: return true
        case .name: return false
        }
    }

    private func sort(_ containers: [ICloudDriveContainer], by key: DriveSortKey) -> [ICloudDriveContainer] {
        containers.sorted { lhs, rhs in
            switch key {
            case .name: return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            case .size: return (lhs.sizeBytes ?? -1, lhs.displayName) > (rhs.sizeBytes ?? -1, rhs.displayName)
            case .modified: return (lhs.modifiedAt ?? .distantPast, lhs.displayName) > (rhs.modifiedAt ?? .distantPast, rhs.displayName)
            }
        }
    }
}

private func bounded(_ value: Int, defaultValue: Int, max: Int) -> Int {
    guard value > 0 else { return defaultValue }
    return Swift.min(value, max)
}
