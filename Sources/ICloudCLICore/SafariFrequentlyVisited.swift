import Foundation

public struct SafariFrequentlyVisitedSite: Codable, Equatable, Sendable {
    public let title: String?
    public let url: String
    public let rank: Int

    public init(title: String?, url: String, rank: Int) {
        self.title = title
        self.url = url
        self.rank = rank
    }
}

public enum SafariFrequentlyVisitedError: Error, LocalizedError, Equatable {
    case missingTopSites(String)
    case unreadableTopSites(String)
    case permissionDenied(String)
    case noSitesFound(String)

    public var errorDescription: String? {
        switch self {
        case .missingTopSites(let path): return "No Safari frequently visited sites file found: \(path)"
        case .unreadableTopSites(let path): return "Could not read Safari frequently visited sites file: \(path)"
        case .permissionDenied(let path): return "Permission denied reading Safari frequently visited sites file: \(path). Grant Full Disk Access to the calling terminal or agent process, then retry."
        case .noSitesFound(let path): return "Safari frequently visited sites file did not contain web URLs: \(path)"
        }
    }
}

public struct SafariFrequentlyVisitedReader: Sendable {
    public let safariDirectory: URL
    public init(safariDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari")) { self.safariDirectory = safariDirectory }

    public func readSites(limit: Int = 20) throws -> [SafariFrequentlyVisitedSite] {
        let fileURL = safariDirectory.appendingPathComponent("TopSites.plist")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw SafariFrequentlyVisitedError.missingTopSites(fileURL.path) }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            if isPermissionDenied(error) {
                throw SafariFrequentlyVisitedError.permissionDenied(fileURL.path)
            }
            throw SafariFrequentlyVisitedError.unreadableTopSites(fileURL.path)
        }
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let sites = SafariFrequentlyVisitedPlistParser().parse(plist)
        guard !sites.isEmpty else { throw SafariFrequentlyVisitedError.noSitesFound(fileURL.path) }
        return Array(sites.prefix(max(0, limit)))
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

public struct SafariFrequentlyVisitedPlistParser: Sendable {
    public init() {}
    public func parse(_ plist: Any) -> [SafariFrequentlyVisitedSite] {
        var candidates: [(title: String?, url: String, score: Double?)] = []
        collect(from: plist, into: &candidates)
        let sorted = candidates.enumerated().sorted { lhs, rhs in
            switch (lhs.element.score, rhs.element.score) {
            case let (left?, right?) where left != right: return left > right
            default: return lhs.offset < rhs.offset
            }
        }
        var seen = Set<String>()
        var result: [SafariFrequentlyVisitedSite] = []
        for item in sorted where seen.insert(item.element.url).inserted {
            result.append(SafariFrequentlyVisitedSite(title: item.element.title?.nilIfEmpty, url: item.element.url, rank: result.count + 1))
        }
        return result
    }

    private func collect(from value: Any, into candidates: inout [(title: String?, url: String, score: Double?)]) {
        if let dictionary = value as? [String: Any] {
            if let url = stringValue(dictionary, keys: ["URL", "url", "URLString", "urlString"]), isWebURL(url) {
                candidates.append((title: stringValue(dictionary, keys: ["Title", "title", "_TITLE", "displayTitle"]), url: url, score: numberValue(dictionary, keys: ["Score", "score", "Frequency", "frequency", "VisitCount", "visitCount"])))
            }
            for nested in dictionary.values { collect(from: nested, into: &candidates) }
            return
        }
        if let array = value as? [Any] { for nested in array { collect(from: nested, into: &candidates) } }
    }

    private func stringValue(_ dictionary: [String: Any], keys: [String]) -> String? { keys.compactMap { dictionary[$0] as? String }.first }
    private func numberValue(_ dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dictionary[key] as? NSNumber { return value.doubleValue }
            if let value = dictionary[key] as? Double { return value }
            if let value = dictionary[key] as? Int { return Double(value) }
        }
        return nil
    }
    private func isWebURL(_ value: String) -> Bool { ["http", "https"].contains(URLComponents(string: value)?.scheme?.lowercased() ?? "") }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
