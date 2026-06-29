import Foundation
import Testing
@testable import ICloudCLICore

private func mobileDocumentsFixtureURL() throws -> URL {
    let fileURL = URL(fileURLWithPath: #filePath)
    let testsDirectory = fileURL.deletingLastPathComponent().deletingLastPathComponent()
    return testsDirectory.appendingPathComponent("Fixtures/MobileDocuments")
}

@Test func listsICloudDriveFilesFromSyntheticFixture() throws {
    let files = try ICloudDriveInventoryReader(rootDirectory: try mobileDocumentsFixtureURL()).listFiles(depth: 2)

    #expect(files.contains { $0.path == "com~apple~CloudDocs/Documents/report.txt" && $0.name == "report.txt" && $0.iCloudStatus == .downloaded })
    #expect(files.contains { $0.path == "com~apple~CloudDocs/Documents/.draft.md.icloud" && $0.name == "draft.md" && $0.iCloudStatus == .evicted && $0.sizeBytes == nil })
}

@Test func limitsICloudDriveFileWalks() throws {
    let files = try ICloudDriveInventoryReader(rootDirectory: try mobileDocumentsFixtureURL()).listFiles(depth: Int.max, limit: 1)

    #expect(files.count == 1)
}

@Test func countsDriveStatusAcrossAllFilesBeforeApplyingListLimits() throws {
    let root = try temporaryDriveInventoryRoot(named: "status-counts")
    defer { try? FileManager.default.removeItem(at: root) }

    let driveRoot = root.appendingPathComponent("Library/Mobile Documents")
    try FileManager.default.createDirectory(at: driveRoot.appendingPathComponent("com~example~App"), withIntermediateDirectories: true)
    try Data("ok".utf8).write(to: driveRoot.appendingPathComponent("com~example~App/one.txt"))
    try Data("ok".utf8).write(to: driveRoot.appendingPathComponent("com~example~App/two.txt"))
    try Data("ok".utf8).write(to: driveRoot.appendingPathComponent("com~example~App/.broken.txt.icloud"))

    let reader = ICloudDriveInventoryReader(rootDirectory: driveRoot)
    let summary = try reader.syncStatus(path: nil)
    let errorFiles = try reader.errorFiles(path: nil, limit: 1)

    #expect(summary.downloadedCount == 2)
    #expect(summary.errorCount == 1)
    #expect(errorFiles.count == 1)
}

@Test func driveErrorResultsKeepResultLimitSeparateFromScanLimit() throws {
    let root = try temporaryDriveInventoryRoot(named: "error-scan-limit")
    defer { try? FileManager.default.removeItem(at: root) }

    let driveRoot = root.appendingPathComponent("Library/Mobile Documents")
    try FileManager.default.createDirectory(at: driveRoot.appendingPathComponent("com~example~App"), withIntermediateDirectories: true)
    try Data("ok".utf8).write(to: driveRoot.appendingPathComponent("com~example~App/.broken-one.txt.icloud"))
    try Data("ok".utf8).write(to: driveRoot.appendingPathComponent("com~example~App/.broken-two.txt.icloud"))
    try Data("ok".utf8).write(to: driveRoot.appendingPathComponent("com~example~App/.broken-three.txt.icloud"))

    let reader = ICloudDriveInventoryReader(rootDirectory: driveRoot)
    let scannedErrorFiles = try reader.errorFiles(path: nil, limit: 10, scanLimit: 2)
    let cappedErrorFiles = try reader.errorFiles(path: nil, limit: 1, scanLimit: 3)

    #expect(scannedErrorFiles.count == 2)
    #expect(cappedErrorFiles.count == 1)
}

@Test func driveSharedResultsUseBoundedTraversalBeforeFiltering() throws {
    let root = try temporaryDriveInventoryRoot(named: "shared-scan-limit")
    defer { try? FileManager.default.removeItem(at: root) }

    let driveRoot = root.appendingPathComponent("Library/Mobile Documents")
    try FileManager.default.createDirectory(at: driveRoot.appendingPathComponent("com~example~App"), withIntermediateDirectories: true)
    try Data("ok".utf8).write(to: driveRoot.appendingPathComponent("com~example~App/alpha.shared.txt"))
    try Data("ok".utf8).write(to: driveRoot.appendingPathComponent("com~example~App/beta.shared.txt"))
    try Data("ok".utf8).write(to: driveRoot.appendingPathComponent("com~example~App/gamma.shared.txt"))

    let reader = ICloudDriveInventoryReader(rootDirectory: driveRoot)
    let scannedSharedItems = try reader.sharedItems(path: nil, limit: 10, scanLimit: 2)
    let cappedSharedItems = try reader.sharedItems(path: nil, limit: 1, scanLimit: 3)

    #expect(scannedSharedItems.count == 2)
    #expect(cappedSharedItems.count == 1)
}

@Test func scopesICloudDriveListToRelativePath() throws {
    let files = try ICloudDriveInventoryReader(rootDirectory: try mobileDocumentsFixtureURL()).listFiles(path: "com~example~Notes", depth: 1)

    #expect(files.count == 1)
    #expect(files.first?.appContainer == "com~example~Notes")
}

@Test func rejectsDrivePathOutsideRoot() throws {
    #expect(throws: DriveInventoryError.invalidPath("/tmp")) {
        try ICloudDriveInventoryReader(rootDirectory: try mobileDocumentsFixtureURL()).listFiles(path: "/tmp", depth: 1)
    }
}

@Test func listsICloudDriveContainersFromSyntheticFixture() throws {
    let containers = try ICloudDriveInventoryReader(rootDirectory: try mobileDocumentsFixtureURL()).listContainers(sortBy: .name)

    #expect(containers.map(\.bundleId).contains("com~apple~CloudDocs"))
    #expect(containers.map(\.bundleId).contains("com~example~Notes"))
    #expect(containers.allSatisfy { $0.sizeBytes == nil })
}

@Test func computesICloudDriveContainerStatsWhenSortingBySize() throws {
    let containers = try ICloudDriveInventoryReader(rootDirectory: try mobileDocumentsFixtureURL()).listContainers(sortBy: .size)

    #expect(containers.contains { $0.bundleId == "com~apple~CloudDocs" && $0.sizeBytes != nil })
}

private func temporaryDriveInventoryRoot(named name: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("icloud-cli-tests")
        .appendingPathComponent(name)
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
