import Foundation
import Testing
@testable import ICloudCLICore

private func shortcutsFixtureURL() throws -> URL {
    let fileURL = URL(fileURLWithPath: #filePath)
    let testsDirectory = fileURL.deletingLastPathComponent().deletingLastPathComponent()
    return testsDirectory.appendingPathComponent("Fixtures/Shortcuts")
}

@Test func listsSyntheticShortcutsFixture() throws {
    let shortcuts = try ShortcutsInventoryReader(shortcutsDirectory: try shortcutsFixtureURL()).listShortcuts()

    #expect(shortcuts.map(\.name) == ["Archive Notes", "Daily Check"])
    #expect(shortcuts.first { $0.name == "Daily Check" }?.actionCount == 2)
    #expect(shortcuts.first { $0.name == "Daily Check" }?.acceptsInput == true)
    #expect(shortcuts.first { $0.name == "Archive Notes" }?.acceptsInput == false)
}

@Test func filtersSyntheticShortcutsByName() throws {
    let shortcuts = try ShortcutsInventoryReader(shortcutsDirectory: try shortcutsFixtureURL()).listShortcuts(namePattern: "daily")

    #expect(shortcuts.map(\.name) == ["Daily Check"])
}
