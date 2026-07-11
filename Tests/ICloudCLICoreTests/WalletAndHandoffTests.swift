import Foundation
import Testing
@testable import ICloudCLICore

private let fixtures = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")

@Test func readsWalletPassFixtures() throws {
    let passes = try WalletPassesReader(passesDirectory: fixtures.appendingPathComponent("Wallet")).listPasses()
    #expect(passes.count == 2)
    #expect(passes.first?.passType == .boardingPass)
    #expect(passes.first?.organizationName == "Example Air")
    #expect(passes.first?.serialNumber == "SYNTH-BOARD-001")
}

@Test func filtersWalletPassesByTypeAndActiveStatus() throws {
    let passes = try WalletPassesReader(passesDirectory: fixtures.appendingPathComponent("Wallet")).listPasses(type: .boardingPass, activeOnly: true, now: ISO8601DateFormatter().date(from: "2026-05-14T00:00:00Z")!)
    #expect(passes.count == 1)
    #expect(passes[0].passType == .boardingPass)
}

@Test func readsHandoffActivityFixture() throws {
    let activities = try HandoffActivityReader(handoffDirectory: fixtures.appendingPathComponent("Handoff")).listActivities(limit: 1)
    #expect(activities.count == 1)
    #expect(activities[0].deviceName == "Example iPhone")
    #expect(activities[0].appBundleId == "com.apple.mobilesafari")
}

@Test func reportsMalformedHandoffJSON() {
    let directory = fixtures.appendingPathComponent("HandoffMalformedJSON")
    #expect(throws: HandoffError.unparseable(directory.path)) {
        try HandoffActivityReader(handoffDirectory: directory).listActivities()
    }
}

@Test func reportsMalformedHandoffPlist() {
    let directory = fixtures.appendingPathComponent("HandoffMalformedPlist")
    #expect(throws: HandoffError.unparseable(directory.path)) {
        try HandoffActivityReader(handoffDirectory: directory).listActivities()
    }
}

@Test func validEmptyHandoffCacheRemainsEmpty() throws {
    let directory = fixtures.appendingPathComponent("HandoffEmpty")
    #expect(try HandoffActivityReader(handoffDirectory: directory).listActivities().isEmpty)
}

@Test func validHandoffActivitySurvivesMalformedNeighbor() throws {
    let directory = fixtures.appendingPathComponent("HandoffMixed")
    let activities = try HandoffActivityReader(handoffDirectory: directory).listActivities()
    #expect(activities.count == 1)
    #expect(activities[0].deviceName == "Example Mac")
}

@Test func rendersWalletAndHandoffText() throws {
    let runner = CommandRunner()
    let pass = WalletPass(passType: .eventTicket, description: "Synthetic Event", organizationName: "Example Venue", relevantDate: nil, expirationDate: nil, serialNumber: "SERIAL")
    #expect(try runner.render([pass], format: .text).contains("eventTicket: Example Venue"))
    let activity = HandoffActivity(deviceName: "Example iPhone", appBundleId: "com.example", appName: "Example", activityType: "test", title: "Draft", url: nil, updatedAt: Date())
    #expect(try runner.render([activity], format: .text).contains("Example iPhone: Example"))
}
