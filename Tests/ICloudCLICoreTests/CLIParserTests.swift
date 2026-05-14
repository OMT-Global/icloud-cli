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
