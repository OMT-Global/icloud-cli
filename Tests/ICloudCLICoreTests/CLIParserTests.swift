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
