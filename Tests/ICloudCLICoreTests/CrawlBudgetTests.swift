import Darwin
import Foundation
import Testing
@testable import ICloudCLICore

@Test func driveCrawlReportsScanBudgetPartialState() throws {
    let root = try crawlFixture(named: "drive-scan", fileCount: 12)
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

    let report = try ICloudDriveInventoryReader(rootDirectory: root).listFilesReport(
        depth: Int.max,
        budget: CrawlBudget(scanLimit: 3, wallClockLimitMilliseconds: 5_000)
    )

    #expect(report.state == .partial)
    #expect(report.scannedCount == 3)
    #expect(report.resultCount == 3)
    #expect(report.totalAvailable == nil)
    #expect(report.scanLimit == 3)
    #expect(report.nextAction?.contains("--scan-limit") == true)
}

@Test func driveCrawlAtExactScanBudgetIsComplete() throws {
    let root = try crawlFixture(named: "drive-exact-scan", fileCount: 3)
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

    let report = try ICloudDriveInventoryReader(rootDirectory: root).listFilesReport(
        depth: Int.max,
        budget: CrawlBudget(scanLimit: 3, wallClockLimitMilliseconds: 5_000)
    )

    #expect(report.state == .complete)
    #expect(report.scannedCount == 3)
    #expect(report.resultCount == 3)
    #expect(report.totalAvailable == 3)
    #expect(report.nextAction == nil)
}

@Test func driveCrawlTimeoutTerminatesBlockedWorker() throws {
    let root = try crawlFixture(named: "drive-worker-timeout", fileCount: 1)
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
    let worker = ProcessIdentifierBox()

    let started = DispatchTime.now().uptimeNanoseconds
    let report = try ICloudDriveInventoryReader(
        rootDirectory: root,
        workerExecutable: URL(fileURLWithPath: "/bin/sleep"),
        workerArguments: ["30"],
        workerStarted: { worker.record($0) }
    ).listFilesReport(
        depth: Int.max,
        budget: CrawlBudget(scanLimit: 100, wallClockLimitMilliseconds: 100)
    )
    let elapsedMilliseconds = Int((DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)

    #expect(report.state == .timeout)
    #expect(report.nextAction?.contains("--timeout-ms") == true)
    #expect(elapsedMilliseconds < 2_000)
    let pid = try #require(worker.value)
    #expect(kill(pid, 0) == -1)
    #expect(errno == ESRCH)
}

private final class ProcessIdentifierBox: @unchecked Sendable {
    private let lock = NSLock()
    private var processIdentifier: Int32?

    var value: Int32? {
        lock.lock(); defer { lock.unlock() }
        return processIdentifier
    }

    func record(_ processIdentifier: Int32) {
        lock.lock(); defer { lock.unlock() }
        self.processIdentifier = processIdentifier
    }
}

@Test func finderTagsPreserveScanAndResultLimits() throws {
    let root = try crawlFixture(named: "tags", fileCount: 8, taggedIndexes: [1, 5])
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

    let report = try FinderTagsReader(driveRoot: root).itemsReport(
        tag: "Red",
        path: nil,
        limit: 1,
        budget: CrawlBudget(scanLimit: 6, wallClockLimitMilliseconds: 5_000)
    )

    #expect(report.providerId == "tags")
    #expect(report.scannedCount == 6)
    #expect(report.resultCount == 1)
    #expect(report.resultLimit == 1)
    #expect(report.totalAvailable == nil)
}

@Test func completedFinderTagCrawlReportsTotalMatchingRows() throws {
    let root = try crawlFixture(named: "tags-total", fileCount: 8, taggedIndexes: [1, 5])
    defer { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }

    let report = try FinderTagsReader(driveRoot: root).itemsReport(
        tag: "Red",
        path: nil,
        limit: 1,
        budget: CrawlBudget(scanLimit: 20, wallClockLimitMilliseconds: 5_000)
    )

    #expect(report.state == .complete)
    #expect(report.scannedCount == 8)
    #expect(report.resultCount == 1)
    #expect(report.totalAvailable == 2)
}

@Test func watchContinuesAfterTimeoutWithRedactedFailure() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("icloud-cli-watch-budget-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let snapshotter: CacheSnapshotter = { command, _ in
        if command == "drive-list" { throw CrawlBudgetExceeded(providerId: "drive", state: .timeout) }
        return "[]"
    }
    let store = CacheWatchStore(outputDirectory: root, snapshotter: snapshotter)

    let statuses = try store.refresh(
        commands: ["drive-list", "photos-screenshots"],
        budget: CrawlBudget(scanLimit: 5, wallClockLimitMilliseconds: 5)
    )

    #expect(statuses.count == 2)
    #expect(statuses[0].ok == false)
    #expect(statuses[0].failure?.code == "timeout")
    #expect(statuses[0].failure?.providerId == "drive")
    #expect(statuses[0].error == "provider crawl timed out")
    #expect(!statuses[0].error!.contains(root.path))
    #expect(statuses[1].ok == true)
    #expect(try store.read(command: "drive-list").failure?.guidance.contains("budget") == true)
}

@Test func parsesExplicitCrawlBudgets() throws {
    let drive = try CLIParser().parse(arguments: ["icloud-cli", "drive", "list", "--scan-limit", "25", "--timeout-ms", "900"])
    guard case .driveList(let driveOptions) = drive else { Issue.record("Expected drive list"); return }
    #expect(driveOptions.budget == CrawlBudget(scanLimit: 25, wallClockLimitMilliseconds: 900))

    let watch = try CLIParser().parse(arguments: ["icloud-cli", "watch", "--once", "--scan-limit", "40", "--timeout-ms", "700"])
    guard case .watch(let watchOptions) = watch else { Issue.record("Expected watch"); return }
    #expect(watchOptions.budget == CrawlBudget(scanLimit: 40, wallClockLimitMilliseconds: 700))
}

private func crawlFixture(named name: String, fileCount: Int, taggedIndexes: Set<Int> = []) throws -> URL {
    let parent = FileManager.default.temporaryDirectory.appendingPathComponent("icloud-cli-crawl-\(name)-\(UUID().uuidString)")
    let root = parent.appendingPathComponent("MobileDocuments")
    let container = root.appendingPathComponent("com~example~App")
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    for index in 0..<fileCount {
        let tag = taggedIndexes.contains(index) ? ".Red" : ""
        try Data("synthetic".utf8).write(to: container.appendingPathComponent(String(format: "%03d%@.txt", index, tag)))
    }
    return root
}
