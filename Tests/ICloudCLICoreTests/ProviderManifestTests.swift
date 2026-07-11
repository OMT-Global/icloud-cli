import Foundation
import Testing
@testable import ICloudCLICore

@Test func parsesProviderListFormats() throws {
    #expect(try CLIParser().parse(arguments: ["icloud-cli", "providers", "list"]) == .providersList(.json))
    #expect(try CLIParser().parse(arguments: ["icloud-cli", "providers", "list", "--format", "text"]) == .providersList(.text))
}

@Test func providerManifestIsVersionedCompleteAndDeterministic() {
    let manifest = ProviderRegistry.manifest
    #expect(manifest.schemaVersion == "icloud-cli.providers.v1")
    #expect(manifest.providers.map(\.id) == manifest.providers.map(\.id).sorted())
    #expect(Set(manifest.providers.map(\.id)) == [
        "account", "backup", "books", "calendar", "contacts", "devices", "drive", "family",
        "findmy", "focus", "freeform", "handoff", "health", "home", "mail", "maps", "messages",
        "music", "news", "notes", "photos", "reminders", "safari", "shortcuts", "stocks", "storage",
        "tags", "voice-memos", "wallet", "weather",
    ])
    #expect(manifest.providers.allSatisfy { !$0.commands.isEmpty && !$0.capabilities.isEmpty })
    #expect(manifest.providers.allSatisfy { $0.accessMode == .readOnly })
    #expect(manifest.providers.first { $0.id == "messages" }?.capabilities.contains("consistent-snapshot") == true)
    #expect(manifest.providers.first { $0.id == "safari" }?.capabilities.contains("consistent-snapshot") == true)
}

@Test func providerManifestJSONContainsMetadataOnly() throws {
    let output = try CommandRunner().render(ProviderRegistry.manifest, format: .json)
    #expect(output.contains("icloud-cli.providers.v1"))
    #expect(!output.contains(FileManager.default.homeDirectoryForCurrentUser.path))
    #expect(!output.contains("accountIdentifier"))
}

@Test func providerManifestRendersReadableText() throws {
    let output = try CommandRunner().render(ProviderRegistry.manifest, format: .text)
    let lines = output.split(separator: "\n")
    #expect(lines.first == "Provider manifest icloud-cli.providers.v1")
    #expect(lines.contains { $0.hasPrefix("photos ") && $0.contains("photos list") })
    #expect(lines.contains { $0.hasPrefix("messages ") && $0.contains("sensitivity=high") })
}

@Test func commandRunnerListsProviders() {
    final class Sink: @unchecked Sendable { var output = ""; var error = "" }
    let sink = Sink()
    let status = CommandRunner(
        output: { sink.output = $0 },
        errorOutput: { sink.error = $0 }
    ).run(arguments: ["icloud-cli", "providers", "list", "--format", "json"])

    #expect(status == 0)
    #expect(sink.error.isEmpty)
    #expect(sink.output.contains("icloud-cli.providers.v1"))
}
