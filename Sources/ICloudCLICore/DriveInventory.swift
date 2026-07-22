import Darwin
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
    case crawlWorkerUnavailable

    public var errorDescription: String? {
        switch self {
        case .missingRoot(let path): return "iCloud Drive root not available: \(path)"
        case .invalidPath(let path): return "Path is outside the iCloud Drive root: \(path)"
        case .crawlWorkerUnavailable: return "Unable to start the bounded iCloud Drive crawl worker"
        }
    }
}

public struct ICloudDriveInventoryReader: Sendable {
    public let rootDirectory: URL
    private let now: @Sendable () -> TimeInterval
    private let workerExecutable: URL?
    private let workerArguments: [String]?
    private let workerStarted: @Sendable (Int32) -> Void

    public init(
        rootDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents"),
        now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.init(rootDirectory: rootDirectory, now: now, workerExecutable: nil)
    }

    init(
        rootDirectory: URL,
        now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        workerExecutable: URL?,
        workerArguments: [String]? = nil,
        workerStarted: @escaping @Sendable (Int32) -> Void = { _ in }
    ) {
        self.rootDirectory = rootDirectory.standardizedFileURL
        self.now = now
        self.workerExecutable = workerExecutable
        self.workerArguments = workerArguments
        self.workerStarted = workerStarted
    }

    public func listFiles(path requestedPath: String? = nil, depth: Int = 2, limit: Int? = nil) throws -> [ICloudDriveFile] {
        let budget = CrawlBudget(
            scanLimit: limit ?? CrawlBudget.defaultDrive.scanLimit,
            wallClockLimitMilliseconds: CrawlBudget.defaultDrive.wallClockLimitMilliseconds
        )
        return try listFilesReport(path: requestedPath, depth: depth, budget: budget).data
    }

    public func listFilesReport(
        path requestedPath: String? = nil,
        depth: Int = 2,
        budget: CrawlBudget = .defaultDrive
    ) throws -> CrawlReport<[ICloudDriveFile]> {
        guard FileManager.default.fileExists(atPath: rootDirectory.path) else { throw DriveInventoryError.missingRoot(rootDirectory.path) }
        let startURL = try scopedURL(for: requestedPath)
        let startedAt = now()
        let startValues = try? startURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        if startValues?.isDirectory != true {
            let file = fileEntry(for: startURL, values: startValues)
            return CrawlReport(providerId: "drive", state: .complete, data: [file], scannedCount: 1, resultCount: 1, totalAvailable: 1, budget: budget, elapsedMilliseconds: elapsedMilliseconds(since: startedAt), nextAction: nil)
        }
        let maxDepth = max(0, depth)
        let walk = try walkFiles(at: startURL, maxDepth: maxDepth, budget: budget, startedAt: startedAt)
        let files = walk.files.sorted { lhs, rhs in lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending }
        let state = walk.termination ?? .complete
        return CrawlReport(
            providerId: "drive",
            state: state,
            data: files,
            scannedCount: walk.scannedCount,
            resultCount: files.count,
            totalAvailable: state == .complete ? walk.scannedCount : nil,
            budget: budget,
            elapsedMilliseconds: elapsedMilliseconds(since: startedAt),
            nextAction: nextAction(for: state)
        )
    }

    public func syncStatus(path requestedPath: String? = nil, limit: Int? = nil) throws -> ICloudDriveSyncSummary {
        let budget = CrawlBudget(scanLimit: limit ?? CrawlBudget.defaultDrive.scanLimit, wallClockLimitMilliseconds: CrawlBudget.defaultDrive.wallClockLimitMilliseconds)
        return try syncStatusReport(path: requestedPath, budget: budget).data
    }

    public func syncStatusReport(path requestedPath: String? = nil, budget: CrawlBudget = .defaultDrive) throws -> CrawlReport<ICloudDriveSyncSummary> {
        let crawl = try listFilesReport(path: requestedPath, depth: Int.max, budget: budget)
        let files = crawl.data
        let summary = ICloudDriveSyncSummary(
            downloadedCount: files.filter { $0.iCloudStatus == .downloaded }.count,
            cloudOnlyCount: files.filter { $0.iCloudStatus == .evicted || $0.iCloudStatus == .notDownloaded }.count,
            downloadingCount: files.filter { $0.iCloudStatus == .downloading }.count,
            uploadedCount: files.filter { $0.iCloudStatus == .uploaded }.count,
            uploadingCount: files.filter { $0.iCloudStatus == .uploading }.count,
            errorCount: files.filter { $0.iCloudStatus == .error }.count,
            unknownCount: files.filter { $0.iCloudStatus == .unknown }.count
        )
        return crawl.replacingData(summary, resultCount: files.count, totalAvailable: crawl.totalAvailable)
    }

    public func errorFiles(path requestedPath: String? = nil, limit: Int = 500, scanLimit: Int? = nil) throws -> [ICloudDriveErrorEntry] {
        let resultLimit = max(1, limit)
        let traversalLimit = scanLimit ?? filteredDriveScanLimit(for: resultLimit)
        let budget = CrawlBudget(scanLimit: traversalLimit, wallClockLimitMilliseconds: CrawlBudget.defaultDrive.wallClockLimitMilliseconds)
        return try errorFilesReport(path: requestedPath, limit: resultLimit, budget: budget).data
    }

    public func errorFilesReport(path requestedPath: String? = nil, limit: Int = 500, budget: CrawlBudget = .defaultDrive) throws -> CrawlReport<[ICloudDriveErrorEntry]> {
        let resultLimit = max(1, limit)
        let crawl = try listFilesReport(path: requestedPath, depth: Int.max, budget: budget)
        let matches = crawl.data.filter { $0.iCloudStatus == .error }
        let results = matches
            .prefix(resultLimit)
            .map { ICloudDriveErrorEntry(path: $0.path, category: "icloud-sync-error") }
        return crawl.replacingData(results, resultCount: results.count, totalAvailable: crawl.state == .complete ? matches.count : nil, resultLimit: resultLimit)
    }

    public func recentFiles(since: String? = nil, limit: Int = 50) throws -> [ICloudDriveFile] {
        let resultLimit = max(1, limit)
        let budget = CrawlBudget(scanLimit: max(200, bounded(limit, defaultValue: 50, max: 1_000) * 5), wallClockLimitMilliseconds: CrawlBudget.defaultDrive.wallClockLimitMilliseconds)
        return try recentFilesReport(since: since, limit: resultLimit, budget: budget).data
    }

    public func recentFilesReport(since: String? = nil, limit: Int = 50, budget: CrawlBudget = .defaultDrive) throws -> CrawlReport<[ICloudDriveFile]> {
        let floor = since.flatMap { ISO8601DateFormatter().date(from: $0) }
        let resultLimit = max(1, limit)
        let crawl = try listFilesReport(depth: Int.max, budget: budget)
        let matches = crawl.data.filter { file in
                guard let floor else { return true }
                return file.modifiedAt.map { $0 >= floor } ?? false
            }
            .sorted { ($0.modifiedAt ?? .distantPast, $0.path) > ($1.modifiedAt ?? .distantPast, $1.path) }
        let results = matches
            .prefix(resultLimit)
            .map { $0 }
        return crawl.replacingData(results, resultCount: results.count, totalAvailable: crawl.state == .complete ? matches.count : nil, resultLimit: resultLimit)
    }

    public func sharedItems(path requestedPath: String? = nil, limit: Int = 500, scanLimit: Int? = nil) throws -> [ICloudDriveSharedItem] {
        let resultLimit = max(1, limit)
        let traversalLimit = scanLimit ?? filteredDriveScanLimit(for: resultLimit)
        let budget = CrawlBudget(scanLimit: traversalLimit, wallClockLimitMilliseconds: CrawlBudget.defaultDrive.wallClockLimitMilliseconds)
        return try sharedItemsReport(path: requestedPath, limit: resultLimit, budget: budget).data
    }

    public func sharedItemsReport(path requestedPath: String? = nil, limit: Int = 500, budget: CrawlBudget = .defaultDrive) throws -> CrawlReport<[ICloudDriveSharedItem]> {
        let resultLimit = max(1, limit)
        let crawl = try listFilesReport(path: requestedPath, depth: Int.max, budget: budget)
        let matches = crawl.data.filter { $0.path.localizedCaseInsensitiveContains(".shared") }
        let results = matches
            .prefix(resultLimit)
            .map { file in
                ICloudDriveSharedItem(path: file.path, owner: nil, role: nil, dateShared: file.modifiedAt, iCloudStatus: file.iCloudStatus)
            }
        return crawl.replacingData(results, resultCount: results.count, totalAvailable: crawl.state == .complete ? matches.count : nil, resultLimit: resultLimit)
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

    private func filteredDriveScanLimit(for resultLimit: Int) -> Int {
        max(200, bounded(resultLimit, defaultValue: 500, max: 2_000) * 5)
    }

    private func walkFiles(at directory: URL, maxDepth: Int, budget: CrawlBudget, startedAt: TimeInterval) throws -> DriveWalkState {
        let box = DriveWalkBox()
        let output = Pipe()
        let process = Process()
        if let workerExecutable {
            process.executableURL = workerExecutable
            process.arguments = workerArguments ?? [directory.path, String(maxDepth)]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
            let workerMaxDepth = maxDepth == .max ? .max : maxDepth + 1
            process.arguments = [directory.path, "-maxdepth", String(workerMaxDepth), "-type", "f", "-print0"]
        }
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let reader = DriveWalkOutputBox()
        let outputHandle = output.fileHandleForReading
        do {
            try process.run()
        } catch {
            throw DriveInventoryError.crawlWorkerUnavailable
        }
        workerStarted(process.processIdentifier)
        DispatchQueue.global(qos: .userInitiated).async {
            defer { reader.finish() }
            while true {
                guard let data = try? outputHandle.read(upToCount: 8_192), !data.isEmpty else { return }
                reader.append(data)
            }
        }

        var pending = Data()
        let deadline = DispatchTime.now() + .milliseconds(budget.wallClockLimitMilliseconds)
        while process.isRunning {
            if !consumeWorkerOutput(&pending, from: reader.drain(), scanLimit: budget.scanLimit, box: box) {
                terminateWorker(process)
                break
            }
            if elapsedMilliseconds(since: startedAt) >= budget.wallClockLimitMilliseconds || DispatchTime.now() >= deadline {
                box.finish(.timeout)
                terminateWorker(process)
                break
            }
            _ = reader.waitForOutput(timeout: .milliseconds(10))
        }

        while !reader.isFinished {
            _ = consumeWorkerOutput(&pending, from: reader.drain(), scanLimit: budget.scanLimit, box: box)
            _ = reader.waitForOutput(timeout: .milliseconds(10))
        }
        _ = consumeWorkerOutput(&pending, from: reader.drain(), scanLimit: budget.scanLimit, box: box)
        if !box.shouldStop {
            box.finish(.complete)
        }
        return box.snapshot()
    }

    private func consumeWorkerOutput(_ pending: inout Data, from data: Data, scanLimit: Int, box: DriveWalkBox) -> Bool {
        pending.append(data)
        while let terminator = pending.firstIndex(of: 0) {
            let pathData = pending.prefix(upTo: terminator)
            pending.removeSubrange(...terminator)
            guard !pathData.isEmpty, let path = String(data: pathData, encoding: .utf8) else { continue }
            let url = URL(fileURLWithPath: path)
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            guard box.append(fileEntry(for: url, values: values), scanLimit: scanLimit) else { return false }
        }
        return true
    }

    private func terminateWorker(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let deadline = DispatchTime.now().uptimeNanoseconds + 100_000_000
        while process.isRunning && DispatchTime.now().uptimeNanoseconds < deadline {
            Thread.sleep(forTimeInterval: 0.005)
        }
        if process.isRunning {
            _ = kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
    }

    private func elapsedMilliseconds(since startedAt: TimeInterval) -> Int {
        max(0, Int((now() - startedAt) * 1_000))
    }

    private func nextAction(for state: CrawlState) -> String? {
        switch state {
        case .complete: return nil
        case .partial: return "Increase --scan-limit or narrow --path to inspect more items."
        case .timeout: return "Increase --timeout-ms or narrow --path to finish the crawl."
        }
    }

    private func fileEntry(for url: URL, values: URLResourceValues?) -> ICloudDriveFile {
        let status = status(for: url)
        return ICloudDriveFile(path: relativePath(for: url), name: displayFileName(for: url), sizeBytes: status == .evicted ? nil : values?.fileSize.map(Int64.init), modifiedAt: values?.contentModificationDate, iCloudStatus: status, appContainer: appContainer(for: url))
    }

    private func status(for url: URL) -> ICloudFileStatus {
        let name = url.lastPathComponent
        if name.hasPrefix(".broken") && name.hasSuffix(".icloud") { return .error }
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

private struct DriveWalkState {
    var files: [ICloudDriveFile] = []
    var scannedCount = 0
    var termination: CrawlState?
}

private final class DriveWalkBox: @unchecked Sendable {
    private let lock = NSLock()
    private var state = DriveWalkState()

    var shouldStop: Bool {
        lock.lock(); defer { lock.unlock() }
        return state.termination != nil
    }

    func append(_ file: ICloudDriveFile, scanLimit: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard state.termination == nil else { return false }
        guard state.scannedCount < scanLimit else {
            state.termination = .partial
            return false
        }
        state.files.append(file)
        state.scannedCount += 1
        return true
    }

    func finish(_ termination: CrawlState) {
        lock.lock(); defer { lock.unlock() }
        guard state.termination == nil else { return }
        state.termination = termination
    }

    func snapshot() -> DriveWalkState {
        lock.lock(); defer { lock.unlock() }
        return state
    }
}

private final class DriveWalkOutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private let outputAvailable = DispatchSemaphore(value: 0)
    private var output = Data()
    private var finished = false

    var isFinished: Bool {
        lock.lock(); defer { lock.unlock() }
        return finished
    }

    func append(_ data: Data) {
        lock.lock()
        output.append(data)
        lock.unlock()
        outputAvailable.signal()
    }

    func drain() -> Data {
        lock.lock(); defer { lock.unlock() }
        let drained = output
        output.removeAll(keepingCapacity: true)
        return drained
    }

    func finish() {
        lock.lock()
        finished = true
        lock.unlock()
        outputAvailable.signal()
    }

    func waitForOutput(timeout: DispatchTimeInterval) -> DispatchTimeoutResult {
        outputAvailable.wait(timeout: .now() + timeout)
    }
}

private extension CrawlReport {
    func replacingData<NewPayload: Codable & Sendable>(
        _ data: NewPayload,
        resultCount: Int,
        totalAvailable: Int?,
        resultLimit: Int? = nil
    ) -> CrawlReport<NewPayload> {
        CrawlReport<NewPayload>(
            providerId: providerId,
            state: state,
            data: data,
            scannedCount: scannedCount,
            resultCount: resultCount,
            totalAvailable: totalAvailable,
            budget: CrawlBudget(scanLimit: scanLimit, wallClockLimitMilliseconds: wallClockLimitMilliseconds),
            resultLimit: resultLimit,
            elapsedMilliseconds: elapsedMilliseconds,
            nextAction: nextAction
        )
    }
}

private func bounded(_ value: Int, defaultValue: Int, max: Int) -> Int {
    guard value > 0 else { return defaultValue }
    return Swift.min(value, max)
}
