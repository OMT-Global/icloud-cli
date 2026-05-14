import Foundation

public struct CommandRunner: Sendable {
    private let parser: CLIParser
    private let output: @Sendable (String) -> Void
    private let errorOutput: @Sendable (String) -> Void

    public init(
        parser: CLIParser = CLIParser(),
        output: @escaping @Sendable (String) -> Void = { print($0) },
        errorOutput: @escaping @Sendable (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
    ) {
        self.parser = parser
        self.output = output
        self.errorOutput = errorOutput
    }

    @discardableResult
    public func run(arguments: [String]) -> Int32 {
        do {
            switch try parser.parse(arguments: arguments) {
            case .help:
                output(CLIHelp.root())
                return 0
            case .version:
                output(CLIHelp.version)
                return 0
            case .cloudTabsProbe(let options):
                let report = CloudTabsProbe(safariDirectory: options.safariDirectory).probe()
                output(try render(report, format: options.format))
                return 0
            case .driveContainers(let options):
                let containers = try ICloudDriveInventoryReader(rootDirectory: options.rootDirectory).listContainers(sortBy: options.sortBy)
                output(try render(containers, format: options.format))
                return 0
            case .driveList(let options):
                let files = try ICloudDriveInventoryReader(rootDirectory: options.rootDirectory).listFiles(path: options.path, depth: options.depth)
                output(try render(files, format: options.format))
                return 0
            case .safariBookmarks(let options):
                let bookmarks = try SafariBookmarksReader(safariDirectory: options.safariDirectory).readBookmarks()
                output(try render(bookmarks, format: options.format))
                return 0
            case .safariFrequentlyVisited(let options):
                let sites = try SafariFrequentlyVisitedReader(safariDirectory: options.safariDirectory).readSites(limit: options.limit)
                output(try render(sites, format: options.format))
                return 0
            case .safariReadingList(let options):
                let items = try SafariBookmarksReader(safariDirectory: options.safariDirectory).readReadingList()
                output(try render(items, format: options.format))
                return 0
            case .safariTabs(let options):
                let tabs = try SafariTabsReader(safariDirectory: options.safariDirectory).readTabs(source: options.source)
                output(try render(tabs, format: options.format))
                return 0
            case .shortcutsList(let options):
                let shortcuts = try ShortcutsInventoryReader(shortcutsDirectory: options.shortcutsDirectory).listShortcuts(namePattern: options.namePattern)
                output(try render(shortcuts, format: options.format))
                return 0
            }
        } catch {
            errorOutput(error.localizedDescription)
            return 1
        }
    }

    public func render(_ tabs: [SafariTab], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(tabs), as: UTF8.self)
        case .text:
            return tabs
                .map { tab in
                    if let title = tab.title {
                        return "\(title) - \(tab.url)"
                    }
                    return tab.url
                }
                .joined(separator: "\n")
        }
    }


    public func render(_ bookmarks: [SafariBookmark], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(bookmarks), as: UTF8.self)
        case .text:
            return bookmarks.map { bookmark in
                let prefix = bookmark.folderPath.isEmpty ? "" : "[\(bookmark.folderPath)] "
                if let title = bookmark.title { return "\(prefix)\(title) - \(bookmark.url)" }
                return "\(prefix)\(bookmark.url)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ items: [SafariReadingListItem], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(items), as: UTF8.self)
        case .text:
            return items.map { item in
                if let title = item.title { return "\(title) - \(item.url)" }
                return item.url
            }.joined(separator: "\n")
        }
    }

    public func render(_ sites: [SafariFrequentlyVisitedSite], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(sites), as: UTF8.self)
        case .text:
            return sites.map { site in
                if let title = site.title { return "#\(site.rank) \(title) - \(site.url)" }
                return "#\(site.rank) \(site.url)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ files: [ICloudDriveFile], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(files), as: UTF8.self)
        case .text:
            return files.map { file in
                let size = file.sizeBytes.map { "\($0) bytes" } ?? "evicted"
                return "[\(file.iCloudStatus.rawValue)] \(file.path) (\(size))"
            }.joined(separator: "\n")
        }
    }

    public func render(_ containers: [ICloudDriveContainer], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(containers), as: UTF8.self)
        case .text:
            return containers.map { container in
                let size = container.sizeBytes.map { "\($0) bytes" } ?? "unknown size"
                return "\(container.displayName) [\(container.bundleId)] - \(size)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ shortcuts: [ShortcutEntry], format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(shortcuts), as: UTF8.self)
        case .text:
            return shortcuts.map { shortcut in
                let input = shortcut.acceptsInput ? "accepts input" : "no input"
                return "\(shortcut.name) - \(shortcut.actionCount) actions, \(input)"
            }.joined(separator: "\n")
        }
    }

    public func render(_ report: CloudTabsProbeReport, format: OutputFormat) throws -> String {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return String(decoding: try encoder.encode(report), as: UTF8.self)
        case .text:
            var lines = [
                "Cloud tabs store: \(report.databasePath)",
                "Exists: \(report.exists ? "yes" : "no")",
                "Readable: \(report.readable ? "yes" : "no")",
            ]
            if let sizeBytes = report.sizeBytes {
                lines.append("Size: \(sizeBytes) bytes")
            }
            if let failureMode = report.failureMode {
                lines.append("Failure mode: \(failureMode)")
            }
            lines.append("Recommended default: \(report.recommendedDefault)")
            lines.append("Permission expectation: \(report.permissionExpectation)")
            return lines.joined(separator: "\n")
        }
    }
}
