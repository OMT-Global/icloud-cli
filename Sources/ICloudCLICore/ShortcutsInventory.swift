import Foundation

public struct ShortcutEntry: Codable, Equatable, Sendable {
    public let name: String
    public let actionCount: Int
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let acceptsInput: Bool
}

public enum ShortcutsInventoryError: Error, LocalizedError, Equatable {
    case missingDirectory(String)
    case permissionDenied(String)

    public var errorDescription: String? {
        switch self {
        case .missingDirectory(let path): return "Shortcuts directory not available: \(path)"
        case .permissionDenied(let path): return "Permission denied reading Shortcuts directory: \(path). Grant Full Disk Access to the calling terminal or agent process, then retry."
        }
    }
}

public struct ShortcutsInventoryReader: Sendable {
    public let shortcutsDirectory: URL

    public init(shortcutsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Shortcuts")) {
        self.shortcutsDirectory = shortcutsDirectory.standardizedFileURL
    }

    public func listShortcuts(namePattern: String? = nil) throws -> [ShortcutEntry] {
        guard FileManager.default.fileExists(atPath: shortcutsDirectory.path) else {
            throw ShortcutsInventoryError.missingDirectory(shortcutsDirectory.path)
        }

        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(at: shortcutsDirectory, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .contentModificationDateKey], options: [])
        } catch CocoaError.fileReadNoPermission {
            throw ShortcutsInventoryError.permissionDenied(shortcutsDirectory.path)
        } catch {
            throw error
        }
        var shortcuts: [ShortcutEntry] = []
        for entry in entries where entry.pathExtension == "shortcut" {
            if let shortcut = try readShortcut(at: entry) {
                shortcuts.append(shortcut)
            }
        }

        if let pattern = namePattern, !pattern.isEmpty {
            shortcuts = shortcuts.filter { $0.name.localizedCaseInsensitiveContains(pattern) }
        }

        return shortcuts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func readShortcut(at url: URL) throws -> ShortcutEntry? {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey, .contentModificationDateKey])
        let plistURL = values?.isDirectory == true ? preferredPlist(in: url) : url
        guard let plistURL else { return nil }
        let data = try Data(contentsOf: plistURL)
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let plist = object as? [String: Any] else { return nil }

        let fallbackName = url.deletingPathExtension().lastPathComponent
        let name = stringValue(plist, keys: ["WFWorkflowName", "name", "Name"]) ?? fallbackName
        let actions = arrayValue(plist, keys: ["WFWorkflowActions", "actions", "Actions"])
        let createdAt = dateValue(plist, keys: ["WFWorkflowCreationDate", "createdAt", "CreatedAt"]) ?? values?.creationDate
        let modifiedAt = dateValue(plist, keys: ["WFWorkflowModificationDate", "modifiedAt", "ModifiedAt"]) ?? values?.contentModificationDate
        let acceptsInput = boolValue(plist, keys: ["WFWorkflowAcceptsInput", "acceptsInput", "AcceptsInput"]) ?? hasWorkflowInput(plist)

        return ShortcutEntry(name: name, actionCount: actions?.count ?? 0, createdAt: createdAt, modifiedAt: modifiedAt, acceptsInput: acceptsInput)
    }

    private func preferredPlist(in directory: URL) -> URL? {
        let candidates = ["Shortcut.plist", "Info.plist", "shortcut.plist"]
        for candidate in candidates {
            let url = directory.appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private func stringValue(_ plist: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = plist[key] as? String, !value.isEmpty { return value }
        }
        return nil
    }

    private func arrayValue(_ plist: [String: Any], keys: [String]) -> [Any]? {
        for key in keys {
            if let value = plist[key] as? [Any] { return value }
        }
        return nil
    }

    private func dateValue(_ plist: [String: Any], keys: [String]) -> Date? {
        for key in keys {
            if let value = plist[key] as? Date { return value }
            if let value = plist[key] as? String { return ISO8601DateFormatter().date(from: value) }
        }
        return nil
    }

    private func boolValue(_ plist: [String: Any], keys: [String]) -> Bool? {
        for key in keys {
            if let value = plist[key] as? Bool { return value }
            if let value = plist[key] as? NSNumber { return value.boolValue }
        }
        return nil
    }

    private func hasWorkflowInput(_ plist: [String: Any]) -> Bool {
        if let classes = plist["WFWorkflowInputContentItemClasses"] as? [Any], !classes.isEmpty { return true }
        if let types = plist["WFWorkflowInputTypes"] as? [Any], !types.isEmpty { return true }
        return false
    }
}
