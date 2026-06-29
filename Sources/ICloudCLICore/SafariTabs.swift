import Foundation

public enum SafariTabSource: String, CaseIterable, Sendable {
    case currentSession = "current-session"
    case lastSession = "last-session"
    case all
}

public struct SafariTab: Codable, Equatable, Sendable {
    public let url: String
    public let title: String?
    public let windowIndex: Int?
    public let tabIndex: Int?
    public let source: String

    public init(url: String, title: String?, windowIndex: Int?, tabIndex: Int?, source: String) {
        self.url = url
        self.title = title
        self.windowIndex = windowIndex
        self.tabIndex = tabIndex
        self.source = source
    }
}

public enum SafariTabsError: Error, LocalizedError, Equatable {
    case noReadableSources([String])
    case noTabsFound([String])
    case noTabsFoundWithUnreadableSources(readable: [String], unreadable: [String])
    case permissionDenied([String])
    case unsupportedFormat(String)

    public var errorDescription: String? {
        switch self {
        case .noReadableSources(let paths):
            return "No readable Safari session files found: \(paths.joined(separator: ", "))"
        case .noTabsFound(let paths):
            return "Readable Safari session files did not contain tabs: \(paths.joined(separator: ", "))"
        case .noTabsFoundWithUnreadableSources(let readable, let unreadable):
            return """
                Readable Safari session files did not contain tabs: \(readable.joined(separator: ", ")); \
                unreadable Safari session files: \(unreadable.joined(separator: ", "))
                """
        case .permissionDenied(let paths):
            return "Permission denied reading Safari session files: \(paths.joined(separator: ", ")). Grant Full Disk Access to the calling terminal or agent process, then retry."
        case .unsupportedFormat(let format):
            return "Unsupported output format: \(format)"
        }
    }
}

public struct SafariTabsReader: Sendable {
    public let safariDirectory: URL

    public init(safariDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")) {
        self.safariDirectory = safariDirectory
    }

    public func readTabs(source: SafariTabSource = .all) throws -> [SafariTab] {
        let files = sessionFiles(for: source)
        var unreadablePaths: [String] = []
        var permissionDeniedPaths: [String] = []
        var readablePaths: [String] = []
        var tabs: [SafariTab] = []

        for file in files {
            do {
                let sourceTabs = try readTabs(from: file.url, sourceName: file.sourceName)
                readablePaths.append(file.url.path)
                tabs.append(contentsOf: sourceTabs)
            } catch CocoaError.fileReadNoSuchFile {
                unreadablePaths.append(file.url.path)
            } catch {
                if isPermissionDenied(error) {
                    permissionDeniedPaths.append(file.url.path)
                } else {
                    unreadablePaths.append(file.url.path)
                }
            }
        }

        if tabs.isEmpty && !files.isEmpty {
            if readablePaths.isEmpty {
                if !permissionDeniedPaths.isEmpty {
                    throw SafariTabsError.permissionDenied(permissionDeniedPaths)
                }
                throw SafariTabsError.noReadableSources(unreadablePaths)
            }
            if !unreadablePaths.isEmpty || !permissionDeniedPaths.isEmpty {
                throw SafariTabsError.noTabsFoundWithUnreadableSources(
                    readable: readablePaths,
                    unreadable: unreadablePaths + permissionDeniedPaths
                )
            }
            throw SafariTabsError.noTabsFound(readablePaths)
        }

        return deduplicate(tabs)
    }

    private func sessionFiles(for source: SafariTabSource) -> [(sourceName: String, url: URL)] {
        let allFiles = [
            ("current-session", safariDirectory.appendingPathComponent("CurrentSession.plist")),
            ("last-session", safariDirectory.appendingPathComponent("LastSession.plist")),
        ]

        switch source {
        case .currentSession:
            return [allFiles[0]]
        case .lastSession:
            return [allFiles[1]]
        case .all:
            return allFiles
        }
    }

    private func readTabs(from fileURL: URL, sourceName: String) throws -> [SafariTab] {
        let data = try Data(contentsOf: fileURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return SafariSessionPlistParser(sourceName: sourceName).parse(plist)
    }

    private func deduplicate(_ tabs: [SafariTab]) -> [SafariTab] {
        var seen = Set<String>()
        var result: [SafariTab] = []

        for tab in tabs {
            let key = [
                tab.source,
                tab.windowIndex.map(String.init) ?? "",
                tab.tabIndex.map(String.init) ?? "",
                tab.url,
            ].joined(separator: "\u{1F}")
            if seen.insert(key).inserted {
                result.append(tab)
            }
        }

        return result
    }
}

private func isPermissionDenied(_ error: Error) -> Bool {
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
        return true
    }
    let message = nsError.localizedDescription.lowercased()
    return message.contains("permission") || message.contains("operation not permitted") || message.contains("authorization denied")
}

public struct SafariSessionPlistParser: Sendable {
    public let sourceName: String

    public init(sourceName: String) {
        self.sourceName = sourceName
    }

    public func parse(_ plist: Any) -> [SafariTab] {
        var tabs: [SafariTab] = []
        parseValue(plist, windowIndex: nil, tabIndex: nil, tabs: &tabs)
        return tabs
    }

    private func parseValue(_ value: Any, windowIndex: Int?, tabIndex: Int?, tabs: inout [SafariTab]) {
        if let dictionary = value as? [String: Any] {
            if let tab = tab(from: dictionary, windowIndex: windowIndex, tabIndex: tabIndex) {
                tabs.append(tab)
                return
            }

            for (key, nested) in dictionary {
                if key.localizedCaseInsensitiveContains("windows"), let windows = nested as? [Any] {
                    for (index, window) in windows.enumerated() {
                        parseValue(window, windowIndex: index, tabIndex: nil, tabs: &tabs)
                    }
                } else if key.localizedCaseInsensitiveContains("tabs"), let tabValues = nested as? [Any] {
                    for (index, tabValue) in tabValues.enumerated() {
                        parseValue(tabValue, windowIndex: windowIndex, tabIndex: index, tabs: &tabs)
                    }
                } else {
                    parseValue(nested, windowIndex: windowIndex, tabIndex: tabIndex, tabs: &tabs)
                }
            }
            return
        }

        if let array = value as? [Any] {
            for (index, nested) in array.enumerated() {
                parseValue(nested, windowIndex: windowIndex, tabIndex: tabIndex ?? index, tabs: &tabs)
            }
        }
    }

    private func tab(from dictionary: [String: Any], windowIndex: Int?, tabIndex: Int?) -> SafariTab? {
        guard let url = stringValue(dictionary, keys: ["TabURL", "URL", "url"]),
            isLikelyWebURL(url)
        else {
            return nil
        }

        let title = stringValue(dictionary, keys: ["TabTitle", "Title", "title", "TabText"])
        return SafariTab(
            url: url,
            title: title?.isEmpty == false ? title : nil,
            windowIndex: windowIndex,
            tabIndex: tabIndex,
            source: sourceName
        )
    }

    private func stringValue(_ dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String {
                return value
            }
        }
        return nil
    }

    private func isLikelyWebURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased()
        else {
            return false
        }

        return ["http", "https"].contains(scheme)
    }
}
