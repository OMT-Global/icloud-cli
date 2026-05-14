import Foundation

public struct ICloudStorageStatus: Codable, Equatable, Sendable {
    public let totalBytes: Int64
    public let usedBytes: Int64
    public let availableBytes: Int64
    public let accountEmail: String?
    public let lastRefreshedAt: Date?
}

public enum ICloudStorageStatusError: Error, LocalizedError, Equatable {
    case unavailable

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "iCloud quota cache not available; ensure iCloud is signed in and has synced recently"
        }
    }
}

public struct ICloudStorageStatusReader: Sendable {
    public let cacheFile: URL

    public init(cacheFile: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/MobileMeAccounts.plist")) {
        self.cacheFile = cacheFile
    }

    public func readStatus() throws -> ICloudStorageStatus {
        guard let plist = NSDictionary(contentsOf: cacheFile) else { throw ICloudStorageStatusError.unavailable }
        if let status = parseStatus(from: plist) { return status }
        throw ICloudStorageStatusError.unavailable
    }

    private func parseStatus(from plist: NSDictionary) -> ICloudStorageStatus? {
        let candidates = nestedDictionaries(in: plist)
        for dictionary in candidates {
            guard let total = int64Value(dictionary["totalBytes"] ?? dictionary["quotaTotalBytes"] ?? dictionary["totalStorageBytes"] ?? dictionary["quotaTotal"]),
                  let used = int64Value(dictionary["usedBytes"] ?? dictionary["quotaUsedBytes"] ?? dictionary["usedStorageBytes"] ?? dictionary["quotaUsed"]) else { continue }
            let available = int64Value(dictionary["availableBytes"] ?? dictionary["quotaAvailableBytes"] ?? dictionary["availableStorageBytes"]) ?? max(0, total - used)
            let email = stringValue(dictionary["accountEmail"] ?? dictionary["AccountID"] ?? dictionary["DSIDAccountEmail"] ?? dictionary["email"])
            let refreshed = dateValue(dictionary["lastRefreshedAt"] ?? dictionary["LastSuccessfulSyncDate"] ?? dictionary["lastUpdated"] ?? dictionary["modifiedAt"])
            return ICloudStorageStatus(totalBytes: total, usedBytes: used, availableBytes: available, accountEmail: email, lastRefreshedAt: refreshed)
        }
        return nil
    }
}

public struct FocusStatus: Codable, Equatable, Sendable {
    public let activeFocus: String?
    public let startedAt: Date?
    public let endsAt: Date?
    public let allFocusModes: [String]
}

public enum FocusStatusError: Error, LocalizedError, Equatable {
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let path): return "Focus status cache is unreadable: \(path)"
        }
    }
}

public struct FocusStatusReader: Sendable {
    public let focusDirectory: URL

    public init(focusDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/DoNotDisturb")) {
        self.focusDirectory = focusDirectory
    }

    public func readStatus() throws -> FocusStatus {
        guard FileManager.default.fileExists(atPath: focusDirectory.path) else { throw FocusStatusError.unreadable(focusDirectory.path) }
        guard let enumerator = FileManager.default.enumerator(at: focusDirectory, includingPropertiesForKeys: [.isRegularFileKey], options: []) else { throw FocusStatusError.unreadable(focusDirectory.path) }
        var dictionaries: [NSDictionary] = []
        for case let url as URL in enumerator where url.pathExtension == "plist" {
            if let dictionary = NSDictionary(contentsOf: url) { dictionaries.append(dictionary) }
        }
        guard !dictionaries.isEmpty else { throw FocusStatusError.unreadable(focusDirectory.path) }

        let all = dictionaries.flatMap { nestedDictionaries(in: $0) }
        let modes = uniqueSorted(all.compactMap { stringValue($0["name"] ?? $0["displayName"] ?? $0["focusName"]) })
        let active = all.first { boolValue($0["active"] ?? $0["isActive"] ?? $0["enabled"]) == true }
        let activeName = active.flatMap { stringValue($0["name"] ?? $0["displayName"] ?? $0["focusName"]) }
        return FocusStatus(activeFocus: activeName, startedAt: active.flatMap { dateValue($0["startedAt"] ?? $0["startDate"]) }, endsAt: active.flatMap { dateValue($0["endsAt"] ?? $0["endDate"]) }, allFocusModes: modes)
    }
}

public struct ICloudDevice: Codable, Equatable, Sendable {
    public let name: String
    public let model: String
    public let osVersion: String?
    public let isCurrentDevice: Bool
    public let lastSeenAt: Date?
}

public enum ICloudDevicesError: Error, LocalizedError, Equatable {
    case unreadable(String)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let path): return "iCloud devices cache is unreadable: \(path)"
        }
    }
}

public struct ICloudDevicesReader: Sendable {
    public let cacheFile: URL

    public init(cacheFile: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/MobileMeAccounts.plist")) {
        self.cacheFile = cacheFile
    }

    public func listDevices() throws -> [ICloudDevice] {
        guard let plist = NSDictionary(contentsOf: cacheFile) else { throw ICloudDevicesError.unreadable(cacheFile.path) }
        let devices = nestedDictionaries(in: plist).compactMap(device(from:))
        if devices.isEmpty { throw ICloudDevicesError.unreadable(cacheFile.path) }
        return devices.sorted { lhs, rhs in lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending }
    }

    private func device(from dictionary: NSDictionary) -> ICloudDevice? {
        guard let name = stringValue(dictionary["name"] ?? dictionary["deviceName"] ?? dictionary["DeviceName"]),
              let model = stringValue(dictionary["model"] ?? dictionary["modelDisplayName"] ?? dictionary["deviceModel"] ?? dictionary["ProductType"]) else { return nil }
        let os = stringValue(dictionary["osVersion"] ?? dictionary["systemVersion"] ?? dictionary["OSVersion"])
        let current = boolValue(dictionary["isCurrentDevice"] ?? dictionary["currentDevice"] ?? dictionary["IsThisDevice"]) ?? false
        let lastSeen = dateValue(dictionary["lastSeenAt"] ?? dictionary["lastSeen"] ?? dictionary["LastSeenDate"])
        return ICloudDevice(name: name, model: model, osVersion: os, isCurrentDevice: current, lastSeenAt: lastSeen)
    }
}

private func nestedDictionaries(in root: Any) -> [NSDictionary] {
    var result: [NSDictionary] = []
    func walk(_ value: Any) {
        if let dictionary = value as? NSDictionary {
            result.append(dictionary)
            for child in dictionary.allValues { walk(child) }
        } else if let array = value as? [Any] {
            for child in array { walk(child) }
        }
    }
    walk(root)
    return result
}

private func int64Value(_ value: Any?) -> Int64? {
    if let number = value as? NSNumber { return number.int64Value }
    if let string = value as? String { return Int64(string) }
    return nil
}

private func stringValue(_ value: Any?) -> String? {
    if let string = value as? String, !string.isEmpty { return string }
    return nil
}

private func boolValue(_ value: Any?) -> Bool? {
    if let bool = value as? Bool { return bool }
    if let number = value as? NSNumber { return number.boolValue }
    if let string = value as? String { return ["true", "yes", "1"].contains(string.lowercased()) }
    return nil
}

private func dateValue(_ value: Any?) -> Date? {
    if let date = value as? Date { return date }
    if let number = value as? NSNumber { return Date(timeIntervalSince1970: number.doubleValue) }
    if let string = value as? String {
        if let date = ISO8601DateFormatter().date(from: string) { return date }
        if let timestamp = Double(string) { return Date(timeIntervalSince1970: timestamp) }
    }
    return nil
}

private func uniqueSorted(_ values: [String]) -> [String] {
    Array(Set(values)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
}
