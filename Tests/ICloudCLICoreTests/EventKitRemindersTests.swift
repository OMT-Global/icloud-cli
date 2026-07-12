import Foundation
import Testing
@testable import ICloudCLICore

@Test func eventKitProviderReadsAndBoundsListsAndReminders() throws {
    let client = FakeReminderEventKitClient(
        state: .fullAccess,
        lists: [
            EventKitReminderList(id: "work", name: "Work"),
            EventKitReminderList(id: "home", name: "Home"),
        ],
        reminders: [
            eventKitReminder(id: "1", title: "Ship PR", listId: "work", listName: "Work", dueAt: "2026-07-12T12:00:00Z"),
            eventKitReminder(id: "2", title: "Done", listId: "work", listName: "Work", completed: true),
            eventKitReminder(id: "3", title: "Buy milk", listId: "home", listName: "Home"),
        ]
    )
    let provider = EventKitRemindersProvider(client: client)

    #expect(try provider.lists(limit: 1).map(\.name) == ["Home"])
    let reminders = try provider.reminders(list: "Work", dueBefore: "2026-07-13T00:00:00Z", dueAfter: nil, includeCompleted: false, limit: 10)
    #expect(reminders.map(\.title) == ["Ship PR"])
    #expect(reminders.first?.notes == nil)
}

@Test func eventKitProviderReportsAuthorizationWithoutRequestingAccess() {
    let provider = EventKitRemindersProvider(client: FakeReminderEventKitClient(state: .denied))
    #expect(provider.authorization().state == .denied)
    #expect(provider.authorization().canRead == false)
    #expect(throws: RemindersProviderError.authorizationRequired(.denied)) {
        try provider.lists(limit: 10)
    }
}

@Test func commandRunnerUsesEventKitAndExposesPermissionSafeSmoke() throws {
    let client = FakeReminderEventKitClient(
        state: .fullAccess,
        lists: [EventKitReminderList(id: "work", name: "Work")],
        reminders: [eventKitReminder(id: "1", title: "Ship PR", listId: "work", listName: "Work")]
    )
    final class Sink: @unchecked Sendable { var output: [String] = []; var errors: [String] = [] }
    let sink = Sink()
    let runner = CommandRunner(remindersClient: client, output: { sink.output.append($0) }, errorOutput: { sink.errors.append($0) })

    #expect(runner.run(arguments: ["icloud-cli", "reminders", "authorization"]) == 0)
    #expect(runner.run(arguments: ["icloud-cli", "reminders", "lists", "--limit", "10"]) == 0)
    #expect(runner.run(arguments: ["icloud-cli", "reminders", "list", "--list", "Work", "--limit", "10"]) == 0)
    #expect(sink.errors.isEmpty)
    #expect(try JSONDecoder().decode(RemindersAuthorizationReport.self, from: Data(sink.output[0].utf8)).state == .fullAccess)
    #expect(try JSONDecoder().decode([ReminderListSummary].self, from: Data(sink.output[1].utf8)).first?.name == "Work")
    #expect(try JSONDecoder().decode([ReminderEntry].self, from: Data(sink.output[2].utf8)).first?.title == "Ship PR")
}

@Test func privateStoreFallbackRequiresExplicitFlag() throws {
    let parsed = try CLIParser().parse(arguments: ["icloud-cli", "reminders", "list", "--degraded-private-store", "--reminders-store", "/tmp/reminders.sqlite"])
    guard case .remindersList(let options) = parsed else { Issue.record("Expected reminders list"); return }
    #expect(options.degradedPrivateStore)
    #expect(options.store.path == "/tmp/reminders.sqlite")
}

@Test func permissionsDoctorReportsEventKitAuthorization() {
    let probes = PermissionsDoctor(remindersAuthorization: .denied).diagnose()
    let reminders = probes.first { $0.command == "reminders list" }
    #expect(reminders?.status == "eventkit-denied")
    #expect(reminders?.paths.isEmpty == true)
    #expect(reminders?.hint.contains("System Settings") == true)
}

private struct FakeReminderEventKitClient: ReminderEventKitClient {
    let state: RemindersAuthorizationState
    var lists: [EventKitReminderList] = []
    var reminders: [EventKitReminderRecord] = []

    func authorizationState() -> RemindersAuthorizationState { state }
    func fetchLists() throws -> [EventKitReminderList] { lists }
    func fetchReminders() throws -> [EventKitReminderRecord] { reminders }
}

private func eventKitReminder(
    id: String,
    title: String,
    listId: String,
    listName: String,
    dueAt: String? = nil,
    completed: Bool = false
) -> EventKitReminderRecord {
    EventKitReminderRecord(id: id, title: title, listId: listId, listName: listName, dueAt: dueAt, isCompleted: completed, priority: 0, notes: nil, createdAt: nil)
}
