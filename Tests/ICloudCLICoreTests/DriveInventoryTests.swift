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
}
