import Foundation

public enum ProviderMaturity: String, Codable, Sendable { case stable, beta, experimental }
public enum ProviderSourceKind: String, Codable, Sendable { case preferences, filesystem, sqlite, mixed }
public enum ProviderAccessMode: String, Codable, Sendable { case readOnly = "read-only" }
public enum ProviderSensitivity: String, Codable, Sendable { case low, moderate, high }

public struct ProviderDescriptor: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let maturity: ProviderMaturity
    public let sourceKind: ProviderSourceKind
    public let accessMode: ProviderAccessMode
    public let sensitivity: ProviderSensitivity
    public let permissionExpectations: [String]
    public let commands: [String]
    public let capabilities: [String]
    public let defaultPolling: Bool
}

public struct ProviderManifest: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let providers: [ProviderDescriptor]
}

public enum ProviderRegistry {
    public static let schemaVersion = "icloud-cli.providers.v1"

    public static let manifest = ProviderManifest(
        schemaVersion: schemaVersion,
        providers: providers.sorted { $0.id < $1.id }
    )

    public static let providers: [ProviderDescriptor] = [
        provider("account", "iCloud Account", .stable, .preferences, .low, ["account status"], ["status"], true),
        provider("backup", "iCloud Backup", .stable, .preferences, .moderate, ["backup status"], ["status"], true),
        provider("books", "Apple Books", .beta, .sqlite, .moderate, ["books collections", "books list"], ["collections", "inventory", "highlights"]),
        provider("calendar", "Calendar", .beta, .sqlite, .high, ["calendar accounts", "calendar list", "calendar events"], ["accounts", "calendars", "events", "date-filtering"]),
        provider("contacts", "Contacts", .beta, .sqlite, .high, ["contacts list"], ["inventory", "search"]),
        provider("devices", "iCloud Devices", .stable, .preferences, .moderate, ["devices list"], ["inventory", "status"], true),
        provider("drive", "iCloud Drive", .stable, .filesystem, .moderate, ["drive containers", "drive errors", "drive list", "drive recents", "drive shared", "drive status"], ["containers", "inventory", "recents", "sharing", "sync-status"], true),
        provider("family", "Family Sharing", .stable, .preferences, .high, ["family status"], ["membership", "status"]),
        provider("findmy", "Find My", .experimental, .sqlite, .high, ["findmy devices", "findmy people"], ["devices", "people", "location"]),
        provider("focus", "Focus", .stable, .preferences, .moderate, ["focus status"], ["status"], true),
        provider("freeform", "Freeform", .beta, .sqlite, .moderate, ["freeform list"], ["inventory", "date-filtering"]),
        provider("handoff", "Handoff", .beta, .filesystem, .moderate, ["handoff list"], ["activity", "recents"], true),
        provider("health", "Health", .experimental, .sqlite, .high, ["health summary"], ["aggregate-summary"]),
        provider("home", "Home", .beta, .sqlite, .high, ["home accessories", "home homes", "home rooms", "home scenes"], ["accessories", "homes", "rooms", "scenes"]),
        provider("mail", "Mail", .beta, .sqlite, .high, ["mail accounts", "mail mailboxes", "mail recent"], ["accounts", "headers", "mailboxes"]),
        provider("maps", "Maps", .beta, .sqlite, .high, ["maps favorites", "maps recents"], ["favorites", "recents", "location"]),
        provider("messages", "Messages", .beta, .sqlite, .high, ["messages conversations", "messages recent"], ["conversations", "messages", "date-filtering"]),
        provider("music", "Music", .beta, .sqlite, .moderate, ["music playlists", "music status", "music tracks"], ["inventory", "playlists", "status"]),
        provider("news", "News", .beta, .sqlite, .moderate, ["news history", "news topics"], ["history", "topics", "date-filtering"]),
        provider("notes", "Notes", .beta, .sqlite, .high, ["notes accounts", "notes folders", "notes list", "notes shared", "notes tags"], ["accounts", "folders", "inventory", "sharing", "tags"]),
        provider("photos", "Photos", .beta, .mixed, .high, ["photos list", "photos screenshots", "photos shared-albums", "photos shared-library"], ["assets", "screenshots", "sharing"]),
        provider("reminders", "Reminders", .beta, .sqlite, .high, ["reminders assigned", "reminders flagged", "reminders list", "reminders lists", "reminders scheduled", "reminders today"], ["inventory", "lists", "smart-views"]),
        provider("safari", "Safari", .beta, .mixed, .high, ["safari bookmarks", "safari cloud-tabs list", "safari cloud-tabs probe", "safari extensions list", "safari frequently-visited", "safari history", "safari profiles list", "safari reading-list", "safari tabs"], ["bookmarks", "cloud-tabs", "extensions", "history", "profiles", "tabs"]),
        provider("shortcuts", "Shortcuts", .stable, .filesystem, .moderate, ["shortcuts list"], ["inventory", "search"], true),
        provider("stocks", "Stocks", .beta, .sqlite, .moderate, ["stocks groups", "stocks watchlist"], ["groups", "watchlist"]),
        provider("storage", "iCloud Storage", .stable, .preferences, .low, ["storage status"], ["quota", "status"], true),
        provider("tags", "Finder Tags", .beta, .mixed, .moderate, ["tags items", "tags list"], ["inventory", "search", "tags"]),
        provider("voice-memos", "Voice Memos", .beta, .sqlite, .high, ["voice-memos list"], ["folders", "inventory", "date-filtering"]),
        provider("wallet", "Wallet", .beta, .filesystem, .high, ["wallet passes"], ["inventory", "type-filtering"]),
        provider("weather", "Weather", .beta, .sqlite, .high, ["weather favorites"], ["favorites", "location"]),
    ]

    private static func provider(
        _ id: String,
        _ displayName: String,
        _ maturity: ProviderMaturity,
        _ sourceKind: ProviderSourceKind,
        _ sensitivity: ProviderSensitivity,
        _ commands: [String],
        _ capabilities: [String],
        _ defaultPolling: Bool = false
    ) -> ProviderDescriptor {
        ProviderDescriptor(
            id: id,
            displayName: displayName,
            maturity: maturity,
            sourceKind: sourceKind,
            accessMode: .readOnly,
            sensitivity: sensitivity,
            permissionExpectations: permissions(for: sourceKind),
            commands: commands.sorted(),
            capabilities: capabilities.sorted(),
            defaultPolling: defaultPolling
        )
    }

    private static func permissions(for sourceKind: ProviderSourceKind) -> [String] {
        switch sourceKind {
        case .preferences: return ["standard-user-access", "full-disk-access-may-be-required"]
        case .filesystem, .sqlite, .mixed: return ["full-disk-access-may-be-required"]
        }
    }
}
