import Foundation
import Testing
@testable import ICloudCLICore

private let fixtures = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures/SystemStatus")

@Test func readsStorageQuotaStatusFixture() throws {
    let status = try ICloudStorageStatusReader(cacheFile: fixtures.appendingPathComponent("MobileMeAccounts.plist")).readStatus()

    #expect(status.totalBytes == 200_000_000_000)
    #expect(status.usedBytes == 75_000_000_000)
    #expect(status.availableBytes == 125_000_000_000)
    #expect(status.accountEmail == "operator@example.com")
}

@Test func readsFocusStatusFixture() throws {
    let status = try FocusStatusReader(focusDirectory: fixtures.appendingPathComponent("Focus")).readStatus()

    #expect(status.activeFocus == "Work")
    #expect(status.allFocusModes == ["Sleep", "Work"])
    #expect(status.endsAt != nil)
}

@Test func readsDevicesFixture() throws {
    let devices = try ICloudDevicesReader(cacheFile: fixtures.appendingPathComponent("MobileMeAccounts.plist")).listDevices()

    #expect(devices.count == 2)
    #expect(devices.first?.name == "Example Mac")
    #expect(devices.first?.isCurrentDevice == true)
}

@Test func rendersStatusCommandsAsText() throws {
    let runner = CommandRunner()
    let storage = ICloudStorageStatus(totalBytes: 200_000_000_000, usedBytes: 75_000_000_000, availableBytes: 125_000_000_000, accountEmail: "operator@example.com", lastRefreshedAt: nil)
    #expect(try runner.render(storage, format: .text).contains("75.0 GB used"))

    let focus = FocusStatus(activeFocus: nil, startedAt: nil, endsAt: nil, allFocusModes: [])
    #expect(try runner.render(focus, format: .text) == "Focus: none")
}
