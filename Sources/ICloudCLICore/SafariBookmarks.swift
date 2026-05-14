import Foundation

public struct SafariBookmark: Codable, Equatable, Sendable {
    public let title: String?
    public let url: String
    public let folderPath: String
    public init(title: String?, url: String, folderPath: String) { self.title = title; self.url = url; self.folderPath = folderPath }
}

public struct SafariReadingListItem: Codable, Equatable, Sendable {
    public let title: String?
    public let url: String
    public let addedAt: String?
    public let lastVisitedAt: String?
    public let isRead: Bool?
    public init(title: String?, url: String, addedAt: String?, lastVisitedAt: String?, isRead: Bool?) { self.title = title; self.url = url; self.addedAt = addedAt; self.lastVisitedAt = lastVisitedAt; self.isRead = isRead }
}

public enum SafariBookmarksError: Error, LocalizedError, Equatable {
    case missingBookmarks(String), unreadableBookmarks(String), noBookmarksFound(String), noReadingListItemsFound(String)
    public var errorDescription: String? {
        switch self {
        case .missingBookmarks(let path): return "No Safari bookmarks file found: \(path)"
        case .unreadableBookmarks(let path): return "Could not read Safari bookmarks file: \(path)"
        case .noBookmarksFound(let path): return "Safari bookmarks file did not contain bookmark URLs: \(path)"
        case .noReadingListItemsFound(let path): return "Safari bookmarks file did not contain reading list URLs: \(path)"
        }
    }
}

public struct SafariBookmarksReader: Sendable {
    public let safariDirectory: URL
    public init(safariDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")) { self.safariDirectory = safariDirectory }
    public func readBookmarks() throws -> [SafariBookmark] {
        let plist = try readBookmarksPlist()
        let bookmarks = SafariBookmarksPlistParser().parseBookmarks(plist)
        guard !bookmarks.isEmpty else { throw SafariBookmarksError.noBookmarksFound(bookmarksPath.path) }
        return bookmarks
    }
    public func readReadingList() throws -> [SafariReadingListItem] {
        let plist = try readBookmarksPlist()
        let items = SafariBookmarksPlistParser().parseReadingList(plist)
        guard !items.isEmpty else { throw SafariBookmarksError.noReadingListItemsFound(bookmarksPath.path) }
        return items
    }
    private var bookmarksPath: URL { safariDirectory.appendingPathComponent("Bookmarks.plist") }
    private func readBookmarksPlist() throws -> Any {
        guard FileManager.default.fileExists(atPath: bookmarksPath.path) else { throw SafariBookmarksError.missingBookmarks(bookmarksPath.path) }
        do { return try PropertyListSerialization.propertyList(from: Data(contentsOf: bookmarksPath), options: [], format: nil) } catch { throw SafariBookmarksError.unreadableBookmarks(bookmarksPath.path) }
    }
}

public struct SafariBookmarksPlistParser: Sendable {
    public init() {}
    public func parseBookmarks(_ plist: Any) -> [SafariBookmark] { var out: [SafariBookmark] = []; walkBookmarks(value: plist, folderPath: [], isReadingList: false, bookmarks: &out); return deduplicate(out) }
    public func parseReadingList(_ plist: Any) -> [SafariReadingListItem] { var out: [SafariReadingListItem] = []; walkReadingList(value: plist, isReadingList: false, items: &out); return deduplicate(out) }

    private func walkBookmarks(value: Any, folderPath: [String], isReadingList: Bool, bookmarks: inout [SafariBookmark]) {
        if let dictionary = value as? [String: Any] {
            let type = stringValue(dictionary, keys: ["WebBookmarkType", "type"])
            let title = titleValue(dictionary)
            let nextIsReadingList = isReadingList || title == "com.apple.ReadingList" || title == "Reading List"
            if type == "WebBookmarkTypeLeaf", !nextIsReadingList, let url = urlValue(dictionary), isWebURL(url) {
                bookmarks.append(SafariBookmark(title: title?.nilIfEmpty, url: url, folderPath: folderPath.joined(separator: "/")))
            }
            let childPath = type == "WebBookmarkTypeList" && title?.isEmpty == false && !nextIsReadingList ? folderPath + [title!] : folderPath
            for nested in dictionary.values { walkBookmarks(value: nested, folderPath: childPath, isReadingList: nextIsReadingList, bookmarks: &bookmarks) }
            return
        }
        if let array = value as? [Any] { for nested in array { walkBookmarks(value: nested, folderPath: folderPath, isReadingList: isReadingList, bookmarks: &bookmarks) } }
    }

    private func walkReadingList(value: Any, isReadingList: Bool, items: inout [SafariReadingListItem]) {
        if let dictionary = value as? [String: Any] {
            let title = titleValue(dictionary)
            let nextIsReadingList = isReadingList || title == "com.apple.ReadingList" || title == "Reading List"
            if nextIsReadingList, stringValue(dictionary, keys: ["WebBookmarkType", "type"]) == "WebBookmarkTypeLeaf", let url = urlValue(dictionary), isWebURL(url) {
                items.append(SafariReadingListItem(title: title?.nilIfEmpty, url: url, addedAt: isoDateString(dictionary, keys: ["DateAdded", "dateAdded", "ReadingListDateAdded"]), lastVisitedAt: isoDateString(dictionary, keys: ["LastVisitedDate", "lastVisitedDate"]), isRead: boolValue(dictionary, keys: ["isRead", "ReadingListIsRead"])))
            }
            for nested in dictionary.values { walkReadingList(value: nested, isReadingList: nextIsReadingList, items: &items) }
            return
        }
        if let array = value as? [Any] { for nested in array { walkReadingList(value: nested, isReadingList: isReadingList, items: &items) } }
    }

    private func deduplicate(_ bookmarks: [SafariBookmark]) -> [SafariBookmark] { var seen = Set<String>(); return bookmarks.filter { seen.insert($0.url).inserted } }
    private func deduplicate(_ items: [SafariReadingListItem]) -> [SafariReadingListItem] { var seen = Set<String>(); return items.filter { seen.insert($0.url).inserted } }
    private func urlValue(_ dictionary: [String: Any]) -> String? { stringValue(dictionary, keys: ["URLString", "URL", "url"]) ?? (dictionary["URIDictionary"] as? [String: Any]).flatMap { stringValue($0, keys: ["URLString", "URL", "url"]) } }
    private func titleValue(_ dictionary: [String: Any]) -> String? { stringValue(dictionary, keys: ["Title", "title", "Name", "name"]) ?? (dictionary["URIDictionary"] as? [String: Any]).flatMap { stringValue($0, keys: ["title", "Title"]) } }
    private func stringValue(_ dictionary: [String: Any], keys: [String]) -> String? { keys.compactMap { dictionary[$0] as? String }.first }
    private func isoDateString(_ dictionary: [String: Any], keys: [String]) -> String? { for key in keys { if let date = dictionary[key] as? Date { return ISO8601DateFormatter().string(from: date) }; if let s = dictionary[key] as? String { return s } }; return nil }
    private func boolValue(_ dictionary: [String: Any], keys: [String]) -> Bool? { for key in keys { if let b = dictionary[key] as? Bool { return b }; if let n = dictionary[key] as? NSNumber { return n.boolValue } }; return nil }
    private func isWebURL(_ value: String) -> Bool { ["http", "https"].contains(URLComponents(string: value)?.scheme?.lowercased() ?? "") }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
