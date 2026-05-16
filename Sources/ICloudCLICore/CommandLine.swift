import Foundation

public enum OutputFormat: String, Sendable {
    case json
    case text
}

public struct SafariTabsOptions: Equatable, Sendable {
    public var source: SafariTabSource
    public var format: OutputFormat
    public var safariDirectory: URL

    public init(source: SafariTabSource = .all, format: OutputFormat = .json, safariDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")) {
        self.source = source
        self.format = format
        self.safariDirectory = safariDirectory
    }
}

public struct SafariBookmarksOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var safariDirectory: URL

    public init(format: OutputFormat = .json, safariDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")) {
        self.format = format
        self.safariDirectory = safariDirectory
    }
}

public struct SafariFrequentlyVisitedOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var safariDirectory: URL
    public var limit: Int

    public init(format: OutputFormat = .json, safariDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari"), limit: Int = 20) {
        self.format = format
        self.safariDirectory = safariDirectory
        self.limit = limit
    }
}

public struct DriveListOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var rootDirectory: URL
    public var path: String?
    public var depth: Int

    public init(format: OutputFormat = .json, rootDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents"), path: String? = nil, depth: Int = 2) {
        self.format = format
        self.rootDirectory = rootDirectory
        self.path = path
        self.depth = depth
    }
}

public struct DriveContainersOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var rootDirectory: URL
    public var sortBy: DriveSortKey

    public init(format: OutputFormat = .json, rootDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents"), sortBy: DriveSortKey = .name) {
        self.format = format
        self.rootDirectory = rootDirectory
        self.sortBy = sortBy
    }
}

public struct ShortcutsListOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var shortcutsDirectory: URL
    public var namePattern: String?

    public init(format: OutputFormat = .json, shortcutsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Shortcuts"), namePattern: String? = nil) {
        self.format = format
        self.shortcutsDirectory = shortcutsDirectory
        self.namePattern = namePattern
    }
}

public struct StorageStatusOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var cacheFile: URL

    public init(format: OutputFormat = .json, cacheFile: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/MobileMeAccounts.plist")) {
        self.format = format
        self.cacheFile = cacheFile
    }
}

public struct FocusStatusOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var focusDirectory: URL

    public init(format: OutputFormat = .json, focusDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb")) {
        self.format = format
        self.focusDirectory = focusDirectory
    }
}

public struct DevicesListOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var cacheFile: URL

    public init(format: OutputFormat = .json, cacheFile: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/MobileMeAccounts.plist")) {
        self.format = format
        self.cacheFile = cacheFile
    }
}

public struct WalletPassesOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var passesDirectory: URL
    public var type: WalletPassType?
    public var activeOnly: Bool

    public init(format: OutputFormat = .json, passesDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Passes"), type: WalletPassType? = nil, activeOnly: Bool = false) {
        self.format = format
        self.passesDirectory = passesDirectory
        self.type = type
        self.activeOnly = activeOnly
    }
}

public struct HandoffListOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var handoffDirectory: URL
    public var limit: Int

    public init(format: OutputFormat = .json, handoffDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.handoff"), limit: Int = 10) {
        self.format = format
        self.handoffDirectory = handoffDirectory
        self.limit = limit
    }
}

public struct CloudTabsProbeOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var safariDirectory: URL

    public init(format: OutputFormat = .json, safariDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")) {
        self.format = format
        self.safariDirectory = safariDirectory
    }
}

public struct PhotosScreenshotsOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var screenshotsDirectory: URL

    public init(format: OutputFormat = .json, screenshotsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/Screenshots")) {
        self.format = format
        self.screenshotsDirectory = screenshotsDirectory
    }
}

public struct PhotosListOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var photosLibrary: URL

    public init(format: OutputFormat = .json, photosLibrary: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/Photos Library.photoslibrary")) {
        self.format = format
        self.photosLibrary = photosLibrary
    }
}

public struct NotesListOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var notesStore: URL
    public var folder: String?
    public var modifiedSince: String?
    public var includeBody: Bool

    public init(format: OutputFormat = .json, notesStore: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Group Containers/group.com.apple.notes/NoteStore.sqlite"), folder: String? = nil, modifiedSince: String? = nil, includeBody: Bool = false) {
        self.format = format
        self.notesStore = notesStore
        self.folder = folder
        self.modifiedSince = modifiedSince
        self.includeBody = includeBody
    }
}

public struct RemindersListOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var store: URL
    public var list: String?
    public var dueBefore: String?
    public var dueAfter: String?
    public var includeCompleted: Bool

    public init(format: OutputFormat = .json, store: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Reminders/reminders.sqlite"), list: String? = nil, dueBefore: String? = nil, dueAfter: String? = nil, includeCompleted: Bool = false) {
        self.format = format
        self.store = store
        self.list = list
        self.dueBefore = dueBefore
        self.dueAfter = dueAfter
        self.includeCompleted = includeCompleted
    }
}

public struct SafariHistoryOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var historyDatabase: URL
    public var confirmSensitive: Bool
    public var since: String?
    public var until: String?
    public var limit: Int
    public var redactURLs: Bool

    public init(format: OutputFormat = .json, historyDatabase: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari/History.db"), confirmSensitive: Bool = false, since: String? = nil, until: String? = nil, limit: Int = 100, redactURLs: Bool = false) {
        self.format = format
        self.historyDatabase = historyDatabase
        self.confirmSensitive = confirmSensitive
        self.since = since
        self.until = until
        self.limit = limit
        self.redactURLs = redactURLs
    }
}

public struct MessagesOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var chatDatabase: URL
    public var confirmSensitive: Bool
    public var includeBody: Bool
    public var since: String?
    public var limit: Int

    public init(format: OutputFormat = .json, chatDatabase: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Messages/chat.db"), confirmSensitive: Bool = false, includeBody: Bool = false, since: String? = nil, limit: Int = 20) {
        self.format = format
        self.chatDatabase = chatDatabase
        self.confirmSensitive = confirmSensitive
        self.includeBody = includeBody
        self.since = since
        self.limit = limit
    }
}

public struct ContactsListOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var addressBookDatabase: URL
    public var search: String?
    public var limit: Int
    public var includeNotes: Bool

    public init(format: OutputFormat = .json, addressBookDatabase: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/AddressBook/AddressBook-v22.abcddb"), search: String? = nil, limit: Int = 50, includeNotes: Bool = false) {
        self.format = format
        self.addressBookDatabase = addressBookDatabase
        self.search = search
        self.limit = limit
        self.includeNotes = includeNotes
    }
}

public struct MapsOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var store: URL
    public var limit: Int

    public init(format: OutputFormat = .json, store: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/com.apple.Maps/Data/Library/Maps/Maps.sqlite"), limit: Int = 20) {
        self.format = format
        self.store = store
        self.limit = limit
    }
}

public struct NewsOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var store: URL
    public var since: String?
    public var limit: Int

    public init(format: OutputFormat = .json, store: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/com.apple.news/Data/Library/Application Support/news.sqlite"), since: String? = nil, limit: Int = 50) {
        self.format = format
        self.store = store
        self.since = since
        self.limit = limit
    }
}

public struct WatchOptions: Equatable, Sendable {
    public var intervalSeconds: Int
    public var outputDirectory: URL
    public var commands: [String]
    public var once: Bool

    public init(intervalSeconds: Int = 60, outputDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".icloud-cli/cache"), commands: [String] = CacheWatchStore.defaultCommands, once: Bool = false) {
        self.intervalSeconds = intervalSeconds
        self.outputDirectory = outputDirectory
        self.commands = commands
        self.once = once
    }
}

public struct CacheOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var outputDirectory: URL
    public var command: String?

    public init(format: OutputFormat = .json, outputDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".icloud-cli/cache"), command: String? = nil) {
        self.format = format
        self.outputDirectory = outputDirectory
        self.command = command
    }
}

public enum CLICommand: Equatable, Sendable {
    case cacheRead(CacheOptions)
    case cacheStatus(CacheOptions)
    case cloudTabsProbe(CloudTabsProbeOptions)
    case contactsList(ContactsListOptions)
    case devicesList(DevicesListOptions)
    case driveContainers(DriveContainersOptions)
    case driveList(DriveListOptions)
    case focusStatus(FocusStatusOptions)
    case handoffList(HandoffListOptions)
    case mapsFavorites(MapsOptions)
    case mapsRecents(MapsOptions)
    case messagesConversations(MessagesOptions)
    case messagesRecent(MessagesOptions)
    case newsHistory(NewsOptions)
    case newsTopics(NewsOptions)
    case notesList(NotesListOptions)
    case photosList(PhotosListOptions)
    case photosScreenshots(PhotosScreenshotsOptions)
    case remindersList(RemindersListOptions)
    case remindersLists(RemindersListOptions)
    case safariBookmarks(SafariBookmarksOptions)
    case safariFrequentlyVisited(SafariFrequentlyVisitedOptions)
    case safariHistory(SafariHistoryOptions)
    case safariReadingList(SafariBookmarksOptions)
    case safariTabs(SafariTabsOptions)
    case shortcutsList(ShortcutsListOptions)
    case storageStatus(StorageStatusOptions)
    case walletPasses(WalletPassesOptions)
    case watch(WatchOptions)
    case help
    case version
}

public enum CLIParseError: Error, LocalizedError, Equatable {
    case unknownCommand(String)
    case missingValue(String)
    case invalidSource(String)
    case invalidFormat(String)
    case invalidPassType(String)

    public var errorDescription: String? {
        switch self {
        case .unknownCommand(let command): return "Unknown command: \(command)"
        case .missingValue(let option): return "Missing value for \(option)"
        case .invalidSource(let source): return "Invalid Safari tabs source: \(source)"
        case .invalidFormat(let format): return "Invalid output format: \(format)"
        case .invalidPassType(let type): return "Invalid wallet pass type: \(type)"
        }
    }
}

public struct CLIParser: Sendable {
    public init() {}

    public func parse(arguments: [String]) throws -> CLICommand {
        var tokens = Array(arguments.dropFirst())
        if tokens.isEmpty || tokens.contains("--help") || tokens.contains("-h") { return .help }
        if tokens == ["--version"] || tokens == ["-V"] { return .version }

        let topCommand = tokens.removeFirst()
        if topCommand == "storage" {
            guard tokens.first == "status" else { throw CLIParseError.unknownCommand((["storage"] + tokens).joined(separator: " ")) }
            tokens.removeFirst()
            return .storageStatus(try parseStorageStatusOptions(tokens))
        }
        if topCommand == "focus" {
            guard tokens.first == "status" else { throw CLIParseError.unknownCommand((["focus"] + tokens).joined(separator: " ")) }
            tokens.removeFirst()
            return .focusStatus(try parseFocusStatusOptions(tokens))
        }
        if topCommand == "devices" {
            guard tokens.first == "list" else { throw CLIParseError.unknownCommand((["devices"] + tokens).joined(separator: " ")) }
            tokens.removeFirst()
            return .devicesList(try parseDevicesListOptions(tokens))
        }
        if topCommand == "wallet" {
            guard tokens.first == "passes" else { throw CLIParseError.unknownCommand((["wallet"] + tokens).joined(separator: " ")) }
            tokens.removeFirst()
            return .walletPasses(try parseWalletPassesOptions(tokens))
        }
        if topCommand == "handoff" {
            guard tokens.first == "list" else { throw CLIParseError.unknownCommand((["handoff"] + tokens).joined(separator: " ")) }
            tokens.removeFirst()
            return .handoffList(try parseHandoffListOptions(tokens))
        }
        if topCommand == "drive" {
            guard let driveCommand = tokens.first else { throw CLIParseError.unknownCommand("drive") }
            tokens.removeFirst()
            switch driveCommand {
            case "list": return .driveList(try parseDriveListOptions(tokens))
            case "containers": return .driveContainers(try parseDriveContainersOptions(tokens))
            default: throw CLIParseError.unknownCommand((["drive", driveCommand] + tokens).joined(separator: " "))
            }
        }
        if topCommand == "shortcuts" {
            guard tokens.first == "list" else { throw CLIParseError.unknownCommand((["shortcuts"] + tokens).joined(separator: " ")) }
            tokens.removeFirst()
            return .shortcutsList(try parseShortcutsListOptions(tokens))
        }
        if topCommand == "photos" {
            guard let photosCommand = tokens.first else { throw CLIParseError.unknownCommand("photos") }
            tokens.removeFirst()
            switch photosCommand {
            case "screenshots": return .photosScreenshots(try parsePhotosScreenshotsOptions(tokens))
            case "list": return .photosList(try parsePhotosListOptions(tokens))
            default: throw CLIParseError.unknownCommand((["photos", photosCommand] + tokens).joined(separator: " "))
            }
        }
        if topCommand == "notes" {
            guard tokens.first == "list" else { throw CLIParseError.unknownCommand((["notes"] + tokens).joined(separator: " ")) }
            tokens.removeFirst()
            return .notesList(try parseNotesListOptions(tokens))
        }
        if topCommand == "reminders" {
            guard let remindersCommand = tokens.first else { throw CLIParseError.unknownCommand("reminders") }
            tokens.removeFirst()
            switch remindersCommand {
            case "list": return .remindersList(try parseRemindersListOptions(tokens))
            case "lists": return .remindersLists(try parseRemindersListOptions(tokens))
            default: throw CLIParseError.unknownCommand((["reminders", remindersCommand] + tokens).joined(separator: " "))
            }
        }
        if topCommand == "messages" {
            guard let messagesCommand = tokens.first else { throw CLIParseError.unknownCommand("messages") }
            tokens.removeFirst()
            switch messagesCommand {
            case "conversations": return .messagesConversations(try parseMessagesOptions(tokens))
            case "recent": return .messagesRecent(try parseMessagesOptions(tokens))
            default: throw CLIParseError.unknownCommand((["messages", messagesCommand] + tokens).joined(separator: " "))
            }
        }
        if topCommand == "contacts" {
            guard tokens.first == "list" else { throw CLIParseError.unknownCommand((["contacts"] + tokens).joined(separator: " ")) }
            tokens.removeFirst()
            return .contactsList(try parseContactsListOptions(tokens))
        }
        if topCommand == "maps" {
            guard let mapsCommand = tokens.first else { throw CLIParseError.unknownCommand("maps") }
            tokens.removeFirst()
            switch mapsCommand {
            case "favorites": return .mapsFavorites(try parseMapsOptions(tokens))
            case "recents": return .mapsRecents(try parseMapsOptions(tokens))
            default: throw CLIParseError.unknownCommand((["maps", mapsCommand] + tokens).joined(separator: " "))
            }
        }
        if topCommand == "news" {
            guard let newsCommand = tokens.first else { throw CLIParseError.unknownCommand("news") }
            tokens.removeFirst()
            switch newsCommand {
            case "history": return .newsHistory(try parseNewsOptions(tokens))
            case "topics": return .newsTopics(try parseNewsOptions(tokens))
            default: throw CLIParseError.unknownCommand((["news", newsCommand] + tokens).joined(separator: " "))
            }
        }
        if topCommand == "watch" {
            return .watch(try parseWatchOptions(tokens))
        }
        if topCommand == "cache" {
            guard let cacheCommand = tokens.first else { throw CLIParseError.unknownCommand("cache") }
            tokens.removeFirst()
            switch cacheCommand {
            case "read": return .cacheRead(try parseCacheOptions(tokens, requiresCommand: true))
            case "status": return .cacheStatus(try parseCacheOptions(tokens, requiresCommand: false))
            default: throw CLIParseError.unknownCommand((["cache", cacheCommand] + tokens).joined(separator: " "))
            }
        }
        guard topCommand == "safari" else { throw CLIParseError.unknownCommand(topCommand) }
        guard let safariCommand = tokens.first else { throw CLIParseError.unknownCommand((["safari"] + tokens).joined(separator: " ")) }
        tokens.removeFirst()

        switch safariCommand {
        case "tabs": return .safariTabs(try parseSafariTabsOptions(tokens))
        case "history": return .safariHistory(try parseSafariHistoryOptions(tokens))
        case "bookmarks": return .safariBookmarks(try parseSafariBookmarksOptions(tokens))
        case "reading-list": return .safariReadingList(try parseSafariBookmarksOptions(tokens))
        case "frequently-visited": return .safariFrequentlyVisited(try parseSafariFrequentlyVisitedOptions(tokens))
        case "cloud-tabs":
            guard tokens.first == "probe" else { throw CLIParseError.unknownCommand((["safari", safariCommand] + tokens).joined(separator: " ")) }
            tokens.removeFirst()
            return .cloudTabsProbe(try parseCloudTabsProbeOptions(tokens))
        default:
            throw CLIParseError.unknownCommand((["safari", safariCommand] + tokens).joined(separator: " "))
        }
    }

    private func parseSafariTabsOptions(_ tokens: [String]) throws -> SafariTabsOptions {
        var options = SafariTabsOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--source":
                let rawValue = try value(after: token, in: tokens, at: &index)
                guard let source = SafariTabSource(rawValue: rawValue) else { throw CLIParseError.invalidSource(rawValue) }
                options.source = source
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--safari-dir": options.safariDirectory = try parseURL(after: token, in: tokens, at: &index)
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseSafariBookmarksOptions(_ tokens: [String]) throws -> SafariBookmarksOptions {
        var options = SafariBookmarksOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--safari-dir": options.safariDirectory = try parseURL(after: token, in: tokens, at: &index)
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseSafariFrequentlyVisitedOptions(_ tokens: [String]) throws -> SafariFrequentlyVisitedOptions {
        var options = SafariFrequentlyVisitedOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--safari-dir": options.safariDirectory = try parseURL(after: token, in: tokens, at: &index)
            case "--limit":
                let rawValue = try value(after: token, in: tokens, at: &index)
                guard let limit = Int(rawValue), limit >= 0 else { throw CLIParseError.missingValue(token) }
                options.limit = limit
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseDriveListOptions(_ tokens: [String]) throws -> DriveListOptions {
        var options = DriveListOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--icloud-root": options.rootDirectory = try parseURL(after: token, in: tokens, at: &index)
            case "--path": options.path = try value(after: token, in: tokens, at: &index)
            case "--depth":
                let rawValue = try value(after: token, in: tokens, at: &index)
                guard let depth = Int(rawValue), depth >= 0 else { throw CLIParseError.missingValue(token) }
                options.depth = depth
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseDriveContainersOptions(_ tokens: [String]) throws -> DriveContainersOptions {
        var options = DriveContainersOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--icloud-root": options.rootDirectory = try parseURL(after: token, in: tokens, at: &index)
            case "--sort-by":
                let rawValue = try value(after: token, in: tokens, at: &index)
                guard let sortBy = DriveSortKey(rawValue: rawValue) else { throw CLIParseError.missingValue(token) }
                options.sortBy = sortBy
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseShortcutsListOptions(_ tokens: [String]) throws -> ShortcutsListOptions {
        var options = ShortcutsListOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--shortcuts-dir": options.shortcutsDirectory = try parseURL(after: token, in: tokens, at: &index)
            case "--name": options.namePattern = try value(after: token, in: tokens, at: &index)
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseStorageStatusOptions(_ tokens: [String]) throws -> StorageStatusOptions {
        var options = StorageStatusOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--cache-file": options.cacheFile = try parseURL(after: token, in: tokens, at: &index)
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseFocusStatusOptions(_ tokens: [String]) throws -> FocusStatusOptions {
        var options = FocusStatusOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--focus-dir": options.focusDirectory = try parseURL(after: token, in: tokens, at: &index)
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseDevicesListOptions(_ tokens: [String]) throws -> DevicesListOptions {
        var options = DevicesListOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--cache-file": options.cacheFile = try parseURL(after: token, in: tokens, at: &index)
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseWalletPassesOptions(_ tokens: [String]) throws -> WalletPassesOptions {
        var options = WalletPassesOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--passes-dir": options.passesDirectory = try parseURL(after: token, in: tokens, at: &index)
            case "--type":
                let raw = try value(after: token, in: tokens, at: &index)
                guard let type = WalletPassType(rawValue: raw) else { throw CLIParseError.invalidPassType(raw) }
                options.type = type
            case "--active-only": options.activeOnly = true
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseHandoffListOptions(_ tokens: [String]) throws -> HandoffListOptions {
        var options = HandoffListOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--handoff-dir": options.handoffDirectory = try parseURL(after: token, in: tokens, at: &index)
            case "--limit": options.limit = Int(try value(after: token, in: tokens, at: &index)) ?? options.limit
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseCloudTabsProbeOptions(_ tokens: [String]) throws -> CloudTabsProbeOptions {
        var options = CloudTabsProbeOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--safari-dir": options.safariDirectory = try parseURL(after: token, in: tokens, at: &index)
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parsePhotosScreenshotsOptions(_ tokens: [String]) throws -> PhotosScreenshotsOptions {
        var options = PhotosScreenshotsOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--screenshots-dir": options.screenshotsDirectory = try parseURL(after: token, in: tokens, at: &index)
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parsePhotosListOptions(_ tokens: [String]) throws -> PhotosListOptions {
        var options = PhotosListOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--photos-library": options.photosLibrary = try parseURL(after: token, in: tokens, at: &index)
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseNotesListOptions(_ tokens: [String]) throws -> NotesListOptions {
        var options = NotesListOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--notes-store": options.notesStore = try parseURL(after: token, in: tokens, at: &index)
            case "--folder": options.folder = try value(after: token, in: tokens, at: &index)
            case "--modified-since": options.modifiedSince = try value(after: token, in: tokens, at: &index)
            case "--include-body": options.includeBody = true
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseRemindersListOptions(_ tokens: [String]) throws -> RemindersListOptions {
        var options = RemindersListOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--reminders-store": options.store = try parseURL(after: token, in: tokens, at: &index)
            case "--list": options.list = try value(after: token, in: tokens, at: &index)
            case "--due-before": options.dueBefore = try value(after: token, in: tokens, at: &index)
            case "--due-after": options.dueAfter = try value(after: token, in: tokens, at: &index)
            case "--completed": options.includeCompleted = true
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseSafariHistoryOptions(_ tokens: [String]) throws -> SafariHistoryOptions {
        var options = SafariHistoryOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--history-db": options.historyDatabase = try parseURL(after: token, in: tokens, at: &index)
            case "--confirm-sensitive": options.confirmSensitive = true
            case "--since": options.since = try value(after: token, in: tokens, at: &index)
            case "--until": options.until = try value(after: token, in: tokens, at: &index)
            case "--limit": options.limit = Int(try value(after: token, in: tokens, at: &index)) ?? options.limit
            case "--redact-urls": options.redactURLs = true
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseMessagesOptions(_ tokens: [String]) throws -> MessagesOptions {
        var options = MessagesOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--chat-db": options.chatDatabase = try parseURL(after: token, in: tokens, at: &index)
            case "--confirm-sensitive": options.confirmSensitive = true
            case "--include-body": options.includeBody = true
            case "--since": options.since = try value(after: token, in: tokens, at: &index)
            case "--limit": options.limit = Int(try value(after: token, in: tokens, at: &index)) ?? options.limit
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseContactsListOptions(_ tokens: [String]) throws -> ContactsListOptions {
        var options = ContactsListOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--addressbook-db": options.addressBookDatabase = try parseURL(after: token, in: tokens, at: &index)
            case "--search": options.search = try value(after: token, in: tokens, at: &index)
            case "--limit": options.limit = Int(try value(after: token, in: tokens, at: &index)) ?? options.limit
            case "--include-notes": options.includeNotes = true
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseMapsOptions(_ tokens: [String]) throws -> MapsOptions {
        var options = MapsOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--maps-store": options.store = try parseURL(after: token, in: tokens, at: &index)
            case "--limit": options.limit = Int(try value(after: token, in: tokens, at: &index)) ?? options.limit
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseNewsOptions(_ tokens: [String]) throws -> NewsOptions {
        var options = NewsOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--news-store": options.store = try parseURL(after: token, in: tokens, at: &index)
            case "--since": options.since = try value(after: token, in: tokens, at: &index)
            case "--limit": options.limit = Int(try value(after: token, in: tokens, at: &index)) ?? options.limit
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseWatchOptions(_ tokens: [String]) throws -> WatchOptions {
        var options = WatchOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--interval":
                let raw = try value(after: token, in: tokens, at: &index)
                options.intervalSeconds = max(10, Int(raw) ?? options.intervalSeconds)
            case "--output-dir": options.outputDirectory = try parseURL(after: token, in: tokens, at: &index)
            case "--commands":
                options.commands = try value(after: token, in: tokens, at: &index)
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            case "--once": options.once = true
            default: throw CLIParseError.unknownCommand(token)
            }
            index += 1
        }
        return options
    }

    private func parseCacheOptions(_ tokens: [String], requiresCommand: Bool) throws -> CacheOptions {
        var options = CacheOptions(); var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "--format": options.format = try parseFormat(after: token, in: tokens, at: &index)
            case "--output-dir": options.outputDirectory = try parseURL(after: token, in: tokens, at: &index)
            default:
                if options.command == nil {
                    options.command = token
                } else {
                    throw CLIParseError.unknownCommand(token)
                }
            }
            index += 1
        }
        if requiresCommand && options.command == nil {
            throw CLIParseError.missingValue("COMMAND")
        }
        return options
    }

    private func parseFormat(after option: String, in tokens: [String], at index: inout Int) throws -> OutputFormat {
        let rawValue = try value(after: option, in: tokens, at: &index)
        guard let format = OutputFormat(rawValue: rawValue) else { throw CLIParseError.invalidFormat(rawValue) }
        return format
    }

    private func parseURL(after option: String, in tokens: [String], at index: inout Int) throws -> URL {
        URL(fileURLWithPath: NSString(string: try value(after: option, in: tokens, at: &index)).expandingTildeInPath)
    }

    private func value(after option: String, in tokens: [String], at index: inout Int) throws -> String {
        let nextIndex = index + 1
        guard nextIndex < tokens.count else { throw CLIParseError.missingValue(option) }
        index = nextIndex
        return tokens[nextIndex]
    }
}

public enum CLIHelp {
    public static let version = "0.1.0"

    public static func root() -> String {
        """
icloud-cli \(version)

Usage:
  icloud-cli storage status [--format json|text] [--cache-file PATH]
  icloud-cli focus status [--format json|text] [--focus-dir PATH]
  icloud-cli devices list [--format json|text] [--cache-file PATH]
  icloud-cli wallet passes [--type PASS_TYPE] [--active-only] [--format json|text] [--passes-dir PATH]
  icloud-cli handoff list [--limit N] [--format json|text] [--handoff-dir PATH]
  icloud-cli drive list [--path PATH] [--depth N] [--format json|text] [--icloud-root PATH]
  icloud-cli drive containers [--sort-by size|modified|name] [--format json|text] [--icloud-root PATH]
  icloud-cli shortcuts list [--name PATTERN] [--format json|text] [--shortcuts-dir PATH]
  icloud-cli photos screenshots [--format json|text] [--screenshots-dir PATH]
  icloud-cli photos list [--format json|text] [--photos-library PATH]
  icloud-cli notes list [--folder NAME] [--modified-since ISO8601] [--include-body] [--format json|text] [--notes-store PATH]
  icloud-cli reminders lists [--format json|text] [--reminders-store PATH]
  icloud-cli reminders list [--list NAME] [--due-before ISO8601] [--due-after ISO8601] [--completed] [--format json|text] [--reminders-store PATH]
  icloud-cli contacts list [--search QUERY] [--limit N] [--include-notes] [--format json|text] [--addressbook-db PATH]
  icloud-cli messages conversations [--format json|text] [--chat-db PATH]
  icloud-cli messages recent [--confirm-sensitive] [--include-body] [--since ISO8601] [--limit N] [--format json|text] [--chat-db PATH]
  icloud-cli maps favorites [--format json|text] [--maps-store PATH]
  icloud-cli maps recents [--limit N] [--format json|text] [--maps-store PATH]
  icloud-cli news history [--since ISO8601] [--limit N] [--format json|text] [--news-store PATH]
  icloud-cli news topics [--format json|text] [--news-store PATH]
  icloud-cli watch [--interval SECONDS] [--output-dir PATH] [--commands COMMAND,...] [--once]
  icloud-cli cache read COMMAND [--format json|text] [--output-dir PATH]
  icloud-cli cache status [--format json|text] [--output-dir PATH]
  icloud-cli safari tabs [--source all|current-session|last-session] [--format json|text] [--safari-dir PATH]
  icloud-cli safari history [--confirm-sensitive] [--since ISO8601] [--until ISO8601] [--limit N] [--redact-urls] [--format json|text] [--history-db PATH]
  icloud-cli safari bookmarks [--format json|text] [--safari-dir PATH]
  icloud-cli safari reading-list [--format json|text] [--safari-dir PATH]
  icloud-cli safari frequently-visited [--limit N] [--format json|text] [--safari-dir PATH]
  icloud-cli safari cloud-tabs probe [--format json|text] [--safari-dir PATH]

Commands:
  storage status Report locally cached iCloud storage quota.
  focus status   Report locally cached Focus / Do Not Disturb status.
  devices list   List locally cached iCloud registered devices.
  wallet passes  List local Wallet pass metadata without barcode or payment credential data.
  handoff list   List local Handoff recent-activity metadata.
  drive list     List files under the local iCloud Drive root without reading file contents.
  drive containers
                 List top-level iCloud app containers.
  shortcuts list List local Shortcuts metadata without executing shortcuts.
  photos screenshots
                 List screenshot file metadata without reading pixels.
  photos list    List local photo/video asset metadata without exporting media.
  notes list     List Notes titles and dates; body requires --include-body.
  reminders list List reminder metadata from a read-only local store.
  contacts list  List contact cards from local metadata.
  messages conversations
                 List message conversation metadata without message bodies.
  messages recent
                 List recent messages only after --confirm-sensitive.
  maps favorites List Maps saved-place metadata.
  maps recents   List Maps recent-place metadata.
  news history   List News reading-history metadata.
  news topics    List followed News topics/channels.
  watch          Refresh local JSON cache files for OpenClaw polling.
  cache read     Read one cached command output.
  cache status   Report age and ok/error state for cached commands.
  safari tabs    Read Safari open tabs from local Safari session files.
  safari history List Safari history only after --confirm-sensitive.
  safari bookmarks
                 Read Safari bookmarks from Bookmarks.plist.
  safari reading-list
                 Read Safari Reading List items from Bookmarks.plist.
  safari frequently-visited
                 Read Safari frequently visited sites from TopSites.plist.
  safari cloud-tabs probe
                 Inspect whether Safari's cross-device tab store is present and readable.
"""
    }
}
