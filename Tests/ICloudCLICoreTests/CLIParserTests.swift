import Foundation
import Testing
@testable import ICloudCLICore

@Test func parsesSafariTabsDefaults() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "safari", "tabs"])

    guard case .safariTabs(let options) = command else {
        Issue.record("Expected safari tabs command")
        return
    }

    #expect(options.source == .all)
    #expect(options.format == .json)
}

@Test func parsesSafariTabsOptions() throws {
    let command = try CLIParser().parse(arguments: [
        "icloud-cli",
        "safari",
        "tabs",
        "--source",
        "last-session",
        "--format",
        "text",
        "--safari-dir",
        "/tmp/safari-fixture",
    ])

    guard case .safariTabs(let options) = command else {
        Issue.record("Expected safari tabs command")
        return
    }

    #expect(options.source == .lastSession)
    #expect(options.format == .text)
    #expect(options.safariDirectory.path == "/tmp/safari-fixture")
}

@Test func rejectsInvalidSource() throws {
    #expect(throws: CLIParseError.invalidSource("icloud")) {
        try CLIParser().parse(arguments: ["icloud-cli", "safari", "tabs", "--source", "icloud"])
    }
}

@Test func parsesCloudTabsProbeOptions() throws {
    let command = try CLIParser().parse(arguments: [
        "icloud-cli",
        "safari",
        "cloud-tabs",
        "probe",
        "--format",
        "text",
        "--safari-dir",
        "/tmp/safari-fixture",
    ])

    guard case .cloudTabsProbe(let options) = command else {
        Issue.record("Expected cloud tabs probe command")
        return
    }

    #expect(options.format == .text)
    #expect(options.safariDirectory.path == "/tmp/safari-fixture")
}

@Test func helpMentionsSafariInventoryCommands() {
    let help = CLIHelp.root()

    #expect(help.contains("icloud-cli safari tabs"))
    #expect(help.contains("icloud-cli safari cloud-tabs probe"))
}

@Test func parsesSafariBookmarksCommand() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "safari", "bookmarks", "--format", "text", "--safari-dir", "/tmp/safari-fixture"])

    guard case .safariBookmarks(let options) = command else {
        Issue.record("Expected safari bookmarks command")
        return
    }

    #expect(options.format == .text)
    #expect(options.safariDirectory.path == "/tmp/safari-fixture")
}

@Test func parsesSafariReadingListCommand() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "safari", "reading-list", "--format", "json"])

    guard case .safariReadingList(let options) = command else {
        Issue.record("Expected safari reading-list command")
        return
    }

    #expect(options.format == .json)
}

@Test func parsesSafariFrequentlyVisitedCommand() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "safari", "frequently-visited", "--limit", "5", "--format", "text"])

    guard case .safariFrequentlyVisited(let options) = command else {
        Issue.record("Expected safari frequently-visited command")
        return
    }

    #expect(options.limit == 5)
    #expect(options.format == .text)
}

@Test func parsesDriveListCommand() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "drive", "list", "--path", "com~apple~CloudDocs", "--depth", "1", "--format", "text", "--icloud-root", "/tmp/mobile-documents"])

    guard case .driveList(let options) = command else {
        Issue.record("Expected drive list command")
        return
    }

    #expect(options.path == "com~apple~CloudDocs")
    #expect(options.depth == 1)
    #expect(options.format == .text)
    #expect(options.rootDirectory.path == "/tmp/mobile-documents")
}

@Test func parsesDriveContainersCommand() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "drive", "containers", "--sort-by", "size", "--format", "json", "--icloud-root", "/tmp/mobile-documents"])

    guard case .driveContainers(let options) = command else {
        Issue.record("Expected drive containers command")
        return
    }

    #expect(options.sortBy == .size)
    #expect(options.format == .json)
    #expect(options.rootDirectory.path == "/tmp/mobile-documents")
}

@Test func parsesShortcutsListCommand() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "shortcuts", "list", "--name", "Daily", "--format", "text", "--shortcuts-dir", "/tmp/shortcuts"])

    guard case .shortcutsList(let options) = command else {
        Issue.record("Expected shortcuts list command")
        return
    }

    #expect(options.namePattern == "Daily")
    #expect(options.format == .text)
    #expect(options.shortcutsDirectory.path == "/tmp/shortcuts")
}


@Test func parsesStorageStatusCommand() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "storage", "status", "--format", "text", "--cache-file", "/tmp/mobileme.plist"])
    guard case .storageStatus(let options) = command else {
        Issue.record("Expected storage status command")
        return
    }
    #expect(options.format == .text)
    #expect(options.cacheFile.path == "/tmp/mobileme.plist")
}

@Test func parsesFocusStatusCommand() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "focus", "status", "--format", "json", "--focus-dir", "/tmp/focus"])
    guard case .focusStatus(let options) = command else {
        Issue.record("Expected focus status command")
        return
    }
    #expect(options.format == .json)
    #expect(options.focusDirectory.path == "/tmp/focus")
}

@Test func parsesDevicesListCommand() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "devices", "list", "--format", "text", "--cache-file", "/tmp/mobileme.plist"])
    guard case .devicesList(let options) = command else {
        Issue.record("Expected devices list command")
        return
    }
    #expect(options.format == .text)
    #expect(options.cacheFile.path == "/tmp/mobileme.plist")
}
