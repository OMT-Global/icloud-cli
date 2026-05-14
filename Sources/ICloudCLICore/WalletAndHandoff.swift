import Foundation

public enum WalletPassType: String, Codable, CaseIterable, Sendable {
    case boardingPass, eventTicket, coupon, storeCard, generic
}

public struct WalletPass: Codable, Equatable, Sendable {
    public let passType: WalletPassType
    public let description: String
    public let organizationName: String
    public let relevantDate: Date?
    public let expirationDate: Date?
    public let serialNumber: String
}

public enum WalletPassesError: Error, LocalizedError, Equatable {
    case unreadable(String)
    public var errorDescription: String? { if case .unreadable(let path) = self { return "Wallet passes directory is unreadable: \(path)" }; return nil }
}

public struct WalletPassesReader: Sendable {
    public let passesDirectory: URL
    public init(passesDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Passes")) { self.passesDirectory = passesDirectory }

    public func listPasses(type: WalletPassType? = nil, activeOnly: Bool = false, now: Date = Date()) throws -> [WalletPass] {
        guard let children = try? FileManager.default.contentsOfDirectory(at: passesDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { throw WalletPassesError.unreadable(passesDirectory.path) }
        let passes = children.filter { $0.pathExtension == "pkpass" }.compactMap(readPass).filter { pass in
            (type == nil || pass.passType == type) && (!activeOnly || pass.expirationDate.map { $0 >= now } ?? true)
        }
        return passes.sorted { ($0.relevantDate ?? .distantPast) > ($1.relevantDate ?? .distantPast) }
    }

    private func readPass(_ url: URL) -> WalletPass? {
        let manifestURL = url.appendingPathComponent("pass.json")
        let data: Data?
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == true {
            data = try? Data(contentsOf: manifestURL)
        } else {
            data = Self.readZippedPassJSON(url)
        }
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let typeRaw = object["passType"] as? String ?? object["type"] as? String,
              let passType = WalletPassType(rawValue: typeRaw),
              let description = object["description"] as? String,
              let organizationName = object["organizationName"] as? String,
              let serialNumber = object["serialNumber"] as? String else { return nil }
        return WalletPass(passType: passType, description: description, organizationName: organizationName, relevantDate: dateValue(object["relevantDate"]), expirationDate: dateValue(object["expirationDate"]), serialNumber: serialNumber)
    }

    private static func readZippedPassJSON(_ url: URL) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path, "pass.json"]
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = Pipe()
        do { try process.run(); process.waitUntilExit() } catch { return nil }
        guard process.terminationStatus == 0 else { return nil }
        return pipe.fileHandleForReading.readDataToEndOfFile()
    }
}

public struct HandoffActivity: Codable, Equatable, Sendable {
    public let deviceName: String
    public let appBundleId: String
    public let appName: String
    public let activityType: String
    public let title: String?
    public let url: String?
    public let updatedAt: Date
}

public enum HandoffError: Error, LocalizedError, Equatable {
    case unreadable(String)
    public var errorDescription: String? { if case .unreadable(let path) = self { return "Handoff cache directory is unreadable: \(path)" }; return nil }
}

public struct HandoffActivityReader: Sendable {
    public let handoffDirectory: URL
    public init(handoffDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.handoff")) { self.handoffDirectory = handoffDirectory }

    public func listActivities(limit: Int = 10) throws -> [HandoffActivity] {
        guard let enumerator = FileManager.default.enumerator(at: handoffDirectory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { throw HandoffError.unreadable(handoffDirectory.path) }
        var activities: [HandoffActivity] = []
        for case let url as URL in enumerator where ["json", "plist"].contains(url.pathExtension) {
            activities.append(contentsOf: readActivities(from: url))
        }
        return Array(activities.sorted { $0.updatedAt > $1.updatedAt }.prefix(max(0, limit)))
    }

    private func readActivities(from url: URL) -> [HandoffActivity] {
        if url.pathExtension == "json", let data = try? Data(contentsOf: url), let object = try? JSONSerialization.jsonObject(with: data) { return parseActivities(object) }
        if let object = NSDictionary(contentsOf: url) { return parseActivities(object) }
        return []
    }

    private func parseActivities(_ value: Any) -> [HandoffActivity] {
        if let array = value as? [Any] { return array.flatMap(parseActivities) }
        if let dict = value as? NSDictionary { return parseActivities(dict as! [String: Any]) }
        if let dict = value as? [String: Any] {
            if let nested = dict["activities"] ?? dict["items"] { return parseActivities(nested) }
            guard let device = stringValue(dict["deviceName"] ?? dict["device"]),
                  let bundle = stringValue(dict["appBundleId"] ?? dict["bundleIdentifier"] ?? dict["bundleId"]),
                  let app = stringValue(dict["appName"] ?? dict["localizedAppName"]),
                  let type = stringValue(dict["activityType"] ?? dict["type"]),
                  let updated = dateValue(dict["updatedAt"] ?? dict["lastUpdated"] ?? dict["timestamp"]) else { return [] }
            return [HandoffActivity(deviceName: device, appBundleId: bundle, appName: app, activityType: type, title: stringValue(dict["title"]), url: stringValue(dict["url"]), updatedAt: updated)]
        }
        return []
    }
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

private func stringValue(_ value: Any?) -> String? {
    if let string = value as? String, !string.isEmpty { return string }
    return nil
}
