import EventKit
import Foundation

public enum RemindersAuthorizationState: String, Codable, Equatable, Sendable {
    case notDetermined = "not-determined"
    case restricted
    case denied
    case writeOnly = "write-only"
    case fullAccess = "full-access"
    case unknown
}

public struct RemindersAuthorizationReport: Codable, Equatable, Sendable {
    public let provider: String
    public let state: RemindersAuthorizationState
    public let canRead: Bool
    public let requestsAccess: Bool
    public let limitations: [String]
    public let nextAction: String?
}

public struct EventKitReminderList: Codable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct EventKitReminderRecord: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let listId: String
    public let listName: String
    public let dueAt: String?
    public let isCompleted: Bool
    public let priority: Int
    public let notes: String?
    public let createdAt: String?

    public init(id: String, title: String, listId: String, listName: String, dueAt: String?, isCompleted: Bool, priority: Int, notes: String?, createdAt: String?) {
        self.id = id
        self.title = title
        self.listId = listId
        self.listName = listName
        self.dueAt = dueAt
        self.isCompleted = isCompleted
        self.priority = priority
        self.notes = notes
        self.createdAt = createdAt
    }
}

public protocol ReminderEventKitClient: Sendable {
    func authorizationState() -> RemindersAuthorizationState
    func fetchLists() throws -> [EventKitReminderList]
    func fetchReminders() throws -> [EventKitReminderRecord]
}

public enum RemindersProviderError: Error, LocalizedError, Equatable {
    case authorizationRequired(RemindersAuthorizationState)
    case fetchTimedOut

    public var errorDescription: String? {
        switch self {
        case .authorizationRequired(let state):
            return "Reminders EventKit read access is \(state.rawValue). Grant Reminders access in System Settings > Privacy & Security > Reminders, then retry."
        case .fetchTimedOut:
            return "Timed out reading Reminders through EventKit."
        }
    }
}

public struct EventKitRemindersProvider: Sendable {
    private let client: any ReminderEventKitClient

    public init(client: any ReminderEventKitClient = SystemReminderEventKitClient()) {
        self.client = client
    }

    public func authorization() -> RemindersAuthorizationReport {
        let state = client.authorizationState()
        return RemindersAuthorizationReport(
            provider: "eventkit",
            state: state,
            canRead: state == .fullAccess,
            requestsAccess: false,
            limitations: [
                "EventKit does not expose private assigned-to-me smart-list semantics.",
                "Private Core Data-only fields are omitted.",
            ],
            nextAction: state == .fullAccess ? nil : "Grant Reminders access in System Settings > Privacy & Security > Reminders."
        )
    }

    public func lists(limit: Int) throws -> [ReminderListSummary] {
        try requireReadAccess()
        let reminders = try client.fetchReminders()
        let counts = Dictionary(grouping: reminders, by: \.listId).mapValues(\.count)
        return try client.fetchLists()
            .map { ReminderListSummary(name: $0.name, itemCount: counts[$0.id, default: 0]) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .prefix(boundedLimit(limit))
            .map { $0 }
    }

    public func reminders(list: String?, dueBefore: String?, dueAfter: String?, includeCompleted: Bool, limit: Int) throws -> [ReminderEntry] {
        try requireReadAccess()
        let before = dueBefore.flatMap { ISO8601DateFormatter().date(from: $0) }
        let after = dueAfter.flatMap { ISO8601DateFormatter().date(from: $0) }
        return try client.fetchReminders()
            .filter { record in
                if let list, record.listName.localizedCaseInsensitiveCompare(list) != .orderedSame { return false }
                if !includeCompleted, record.isCompleted { return false }
                let due = record.dueAt.flatMap { ISO8601DateFormatter().date(from: $0) }
                if let before, due.map({ $0 > before }) ?? true { return false }
                if let after, due.map({ $0 < after }) ?? true { return false }
                return true
            }
            .sorted { ($0.dueAt ?? "9999", $0.title, $0.id) < ($1.dueAt ?? "9999", $1.title, $1.id) }
            .prefix(boundedLimit(limit))
            .map { ReminderEntry(title: $0.title, listName: $0.listName, dueAt: $0.dueAt, isCompleted: $0.isCompleted, priority: $0.priority, notes: $0.notes, createdAt: $0.createdAt) }
    }

    private func requireReadAccess() throws {
        let state = client.authorizationState()
        guard state == .fullAccess else { throw RemindersProviderError.authorizationRequired(state) }
    }

    private func boundedLimit(_ value: Int) -> Int {
        max(1, min(value, 1_000))
    }
}

public final class SystemReminderEventKitClient: ReminderEventKitClient, @unchecked Sendable {
    private let store: EKEventStore
    private let fetchTimeout: TimeInterval

    public init(store: EKEventStore = EKEventStore(), fetchTimeout: TimeInterval = 5) {
        self.store = store
        self.fetchTimeout = max(0.1, fetchTimeout)
    }

    public func authorizationState() -> RemindersAuthorizationState {
        Self.authorizationState()
    }

    public static func authorizationState() -> RemindersAuthorizationState {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .writeOnly: return .writeOnly
        case .fullAccess, .authorized: return .fullAccess
        @unknown default: return .unknown
        }
    }

    public func fetchLists() throws -> [EventKitReminderList] {
        store.calendars(for: .reminder).map { EventKitReminderList(id: $0.calendarIdentifier, name: $0.title) }
    }

    public func fetchReminders() throws -> [EventKitReminderRecord] {
        let result = ReminderFetchBox()
        let completed = DispatchSemaphore(value: 0)
        store.fetchReminders(matching: store.predicateForReminders(in: nil)) { reminders in
            result.value = reminders ?? []
            completed.signal()
        }
        guard completed.wait(timeout: .now() + fetchTimeout) == .success else { throw RemindersProviderError.fetchTimedOut }
        return result.value.map { reminder in
            EventKitReminderRecord(
                id: reminder.calendarItemIdentifier,
                title: reminder.title,
                listId: reminder.calendar.calendarIdentifier,
                listName: reminder.calendar.title,
                dueAt: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }.map { ISO8601DateFormatter().string(from: $0) },
                isCompleted: reminder.isCompleted,
                priority: reminder.priority,
                notes: reminder.notes,
                createdAt: reminder.creationDate.map { ISO8601DateFormatter().string(from: $0) }
            )
        }
    }
}

private final class ReminderFetchBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [EKReminder] = []
    var value: [EKReminder] {
        get { lock.lock(); defer { lock.unlock() }; return storage }
        set { lock.lock(); defer { lock.unlock() }; storage = newValue }
    }
}
