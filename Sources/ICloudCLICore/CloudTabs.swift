import Foundation

public struct CloudTabsProbeReport: Codable, Equatable, Sendable {
    public let databasePath: String
    public let exists: Bool
    public let readable: Bool
    public let sizeBytes: Int64?
    public let localTabSources: [String]
    public let crossDeviceTabSources: [String]
    public let recommendedDefault: String
    public let permissionExpectation: String
    public let failureMode: String?

    public init(
        databasePath: String,
        exists: Bool,
        readable: Bool,
        sizeBytes: Int64?,
        localTabSources: [String],
        crossDeviceTabSources: [String],
        recommendedDefault: String,
        permissionExpectation: String,
        failureMode: String?
    ) {
        self.databasePath = databasePath
        self.exists = exists
        self.readable = readable
        self.sizeBytes = sizeBytes
        self.localTabSources = localTabSources
        self.crossDeviceTabSources = crossDeviceTabSources
        self.recommendedDefault = recommendedDefault
        self.permissionExpectation = permissionExpectation
        self.failureMode = failureMode
    }
}

public struct CloudTabsProbe: Sendable {
    public let safariDirectory: URL

    public init(safariDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")) {
        self.safariDirectory = safariDirectory
    }

    public func probe() -> CloudTabsProbeReport {
        let databaseURL = safariDirectory.appendingPathComponent("CloudTabs.db")
        let databasePath = databaseURL.path
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: databasePath)
        let readable = exists && fileManager.isReadableFile(atPath: databasePath)
        let sizeBytes = fileSize(at: databaseURL, fileManager: fileManager)

        return CloudTabsProbeReport(
            databasePath: databasePath,
            exists: exists,
            readable: readable,
            sizeBytes: sizeBytes,
            localTabSources: [
                "CurrentSession.plist",
                "LastSession.plist",
            ],
            crossDeviceTabSources: [
                "CloudTabs.db",
            ],
            recommendedDefault: "Keep `icloud-cli safari tabs` local-session only; add `--include-cloud` only after schema parsing is fixture-backed.",
            permissionExpectation: "Reading Safari sync storage is expected to require Full Disk Access for the calling terminal or agent process.",
            failureMode: failureMode(exists: exists, readable: readable)
        )
    }

    private func fileSize(at url: URL, fileManager: FileManager) -> Int64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber
        else {
            return nil
        }
        return size.int64Value
    }

    private func failureMode(exists: Bool, readable: Bool) -> String? {
        if !exists {
            return "cloud-tabs-store-missing"
        }
        if !readable {
            return "cloud-tabs-store-unreadable"
        }
        return nil
    }
}
