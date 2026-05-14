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

public struct CloudTabsProbeOptions: Equatable, Sendable {
    public var format: OutputFormat
    public var safariDirectory: URL

    public init(format: OutputFormat = .json, safariDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")) {
        self.format = format
        self.safariDirectory = safariDirectory
    }
}

public enum CLICommand: Equatable, Sendable {
    case cloudTabsProbe(CloudTabsProbeOptions)
    case driveContainers(DriveContainersOptions)
    case driveList(DriveListOptions)
    case safariBookmarks(SafariBookmarksOptions)
    case safariFrequentlyVisited(SafariFrequentlyVisitedOptions)
    case safariReadingList(SafariBookmarksOptions)
    case safariTabs(SafariTabsOptions)
    case shortcutsList(ShortcutsListOptions)
    case help
    case version
}

public enum CLIParseError: Error, LocalizedError, Equatable {
    case unknownCommand(String)
    case missingValue(String)
    case invalidSource(String)
    case invalidFormat(String)

    public var errorDescription: String? {
        switch self {
        case .unknownCommand(let command): return "Unknown command: \(command)"
        case .missingValue(let option): return "Missing value for \(option)"
        case .invalidSource(let source): return "Invalid Safari tabs source: \(source)"
        case .invalidFormat(let format): return "Invalid output format: \(format)"
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
        guard topCommand == "safari" else { throw CLIParseError.unknownCommand(topCommand) }
        guard let safariCommand = tokens.first else { throw CLIParseError.unknownCommand((["safari"] + tokens).joined(separator: " ")) }
        tokens.removeFirst()

        switch safariCommand {
        case "tabs": return .safariTabs(try parseSafariTabsOptions(tokens))
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
  icloud-cli drive list [--path PATH] [--depth N] [--format json|text] [--icloud-root PATH]
  icloud-cli drive containers [--sort-by size|modified|name] [--format json|text] [--icloud-root PATH]
  icloud-cli shortcuts list [--name PATTERN] [--format json|text] [--shortcuts-dir PATH]
  icloud-cli safari tabs [--source all|current-session|last-session] [--format json|text] [--safari-dir PATH]
  icloud-cli safari bookmarks [--format json|text] [--safari-dir PATH]
  icloud-cli safari reading-list [--format json|text] [--safari-dir PATH]
  icloud-cli safari frequently-visited [--limit N] [--format json|text] [--safari-dir PATH]
  icloud-cli safari cloud-tabs probe [--format json|text] [--safari-dir PATH]

Commands:
  drive list     List files under the local iCloud Drive root without reading file contents.
  drive containers
                 List top-level iCloud app containers.
  shortcuts list List local Shortcuts metadata without executing shortcuts.
  safari tabs    Read Safari open tabs from local Safari session files.
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
