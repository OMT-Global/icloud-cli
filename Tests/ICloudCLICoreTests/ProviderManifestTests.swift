import Foundation
import Testing
@testable import ICloudCLICore

@Test func parsesProviderListFormats() throws {
    #expect(try CLIParser().parse(arguments: ["icloud-cli", "providers", "list"]) == .providersList(.json))
    #expect(try CLIParser().parse(arguments: ["icloud-cli", "providers", "list", "--format", "text"]) == .providersList(.text))
    #expect(try CLIParser().parse(arguments: ["icloud-cli", "providers", "external-manifest"]) == .providersExternalManifest(.json))
    #expect(try CLIParser().parse(arguments: ["icloud-cli", "providers", "external-manifest", "--format", "text"]) == .providersExternalManifest(.text))
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
    let reminders = manifest.providers.first { $0.id == "reminders" }
    #expect(reminders?.sourceKind == .mixed)
    #expect(reminders?.commands.contains("reminders authorization") == true)
    #expect(reminders?.capabilities.contains("eventkit-primary") == true)
    #expect(reminders?.permissionExpectations == ["eventkit-reminders-read", "full-disk-access-only-for-explicit-degraded-fallback"])
    let photos = manifest.providers.first { $0.id == "photos" }
    #expect(photos?.commands.contains("photos authorization") == true)
    #expect(photos?.capabilities.contains("photokit-primary") == true)
    #expect(manifest.providers.first { $0.id == "messages" }?.capabilities.contains("consistent-snapshot") == true)
    #expect(manifest.providers.first { $0.id == "safari" }?.capabilities.contains("consistent-snapshot") == true)
    #expect(manifest.providers.first { $0.id == "drive" }?.capabilities.contains("bounded-crawl") == true)
    #expect(manifest.providers.first { $0.id == "tags" }?.capabilities.contains("bounded-crawl") == true)
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

@Test func externalControlPlaneManifestIsDerivedFromProviderRegistry() throws {
    let manifest = ExternalControlPlaneRegistry.manifest
    #expect(manifest.schemaVersion == "icloud-cli.openclaw.external.v1")
    #expect(manifest.providerManifest == ProviderRegistry.manifest)
    #expect(manifest.actions.map(\.id) == ["discover", "status", "doctor", "sync", "query"])
    #expect(manifest.actions.allSatisfy { $0.localOnly && $0.retention == .localOnly })
    #expect(manifest.actions.allSatisfy { $0.errorShape == .structuredActionErrorV1 && $0.timeoutSeconds > 0 })

    let sync = try #require(manifest.actions.first { $0.id == "sync" })
    #expect(sync.availability == .unavailable)
    #expect(sync.command == nil)

    let query = try #require(manifest.actions.first { $0.id == "query" })
    #expect(query.confirmation == .sensitiveProviderConfirmation)
    #expect(query.providerCommandSource == "providerManifest.providers[].commands")
}

@Test func externalControlPlaneManifestMatchesSyntheticContractFixture() throws {
    struct Fixture: Decodable {
        let schemaVersion: String
        let actionIDs: [String]
        let allActionsLocalOnly: Bool
    }

    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/OpenClaw/external-manifest-contract-v1.json")
    let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: fixtureURL))
    let manifest = ExternalControlPlaneRegistry.manifest

    #expect(manifest.schemaVersion == fixture.schemaVersion)
    #expect(manifest.actions.map(\.id) == fixture.actionIDs)
    #expect(manifest.actions.allSatisfy { $0.localOnly } == fixture.allActionsLocalOnly)
}

@Test func commandRunnerEmitsExternalControlPlaneManifest() throws {
    final class Sink: @unchecked Sendable { var output = ""; var error = "" }
    let sink = Sink()
    let status = CommandRunner(
        output: { sink.output = $0 },
        errorOutput: { sink.error = $0 }
    ).run(arguments: ["icloud-cli", "providers", "external-manifest", "--format", "json"])

    #expect(status == 0)
    #expect(sink.error.isEmpty)
    let manifest = try JSONDecoder().decode(ExternalControlPlaneManifest.self, from: Data(sink.output.utf8))
    #expect(manifest == ExternalControlPlaneRegistry.manifest)
}
