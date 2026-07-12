import Foundation

public enum ExternalActionAvailability: String, Codable, Equatable, Sendable {
    case available
    case unavailable
}

public enum ExternalActionConfirmation: String, Codable, Equatable, Sendable {
    case none
    case explicitOperatorConfirmation = "explicit-operator-confirmation"
    case sensitiveProviderConfirmation = "sensitive-provider-confirmation"
}

public enum ExternalActionRedaction: String, Codable, Equatable, Sendable {
    case metadataOnly = "metadata-only"
    case safeSummary = "safe-summary"
    case providerDefined = "provider-defined"
}

public enum ExternalActionRetention: String, Codable, Equatable, Sendable {
    case localOnly = "local-only"
}

public enum ExternalActionErrorShape: String, Codable, Equatable, Sendable {
    case structuredActionErrorV1 = "structured-action-error-v1"
}

public struct ExternalActionDescriptor: Codable, Equatable, Sendable {
    public let id: String
    public let availability: ExternalActionAvailability
    public let command: [String]?
    public let providerCommandSource: String?
    public let localOnly: Bool
    public let confirmation: ExternalActionConfirmation
    public let redaction: ExternalActionRedaction
    public let errorShape: ExternalActionErrorShape
    public let timeoutSeconds: Int
    public let retention: ExternalActionRetention
}

public struct ExternalControlPlaneManifest: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let providerManifest: ProviderManifest
    public let actions: [ExternalActionDescriptor]
}

public enum ExternalControlPlaneRegistry {
    public static let schemaVersion = "icloud-cli.openclaw.external.v1"

    public static let manifest = ExternalControlPlaneManifest(
        schemaVersion: schemaVersion,
        providerManifest: ProviderRegistry.manifest,
        actions: [
            action(
                id: "discover",
                command: ["providers", "list", "--format", "json"],
                confirmation: .none,
                redaction: .metadataOnly,
                timeoutSeconds: 10
            ),
            action(
                id: "status",
                command: ["snapshot", "--redaction", "safe", "--format", "json"],
                confirmation: .none,
                redaction: .safeSummary,
                timeoutSeconds: 30
            ),
            action(
                id: "doctor",
                command: ["permissions", "doctor", "--format", "json"],
                confirmation: .none,
                redaction: .metadataOnly,
                timeoutSeconds: 10
            ),
            action(
                id: "sync",
                availability: .unavailable,
                confirmation: .explicitOperatorConfirmation,
                redaction: .metadataOnly,
                timeoutSeconds: 120
            ),
            action(
                id: "query",
                providerCommandSource: "providerManifest.providers[].commands",
                confirmation: .sensitiveProviderConfirmation,
                redaction: .providerDefined,
                timeoutSeconds: 30
            ),
        ]
    )

    private static func action(
        id: String,
        availability: ExternalActionAvailability = .available,
        command: [String]? = nil,
        providerCommandSource: String? = nil,
        confirmation: ExternalActionConfirmation,
        redaction: ExternalActionRedaction,
        timeoutSeconds: Int
    ) -> ExternalActionDescriptor {
        ExternalActionDescriptor(
            id: id,
            availability: availability,
            command: command,
            providerCommandSource: providerCommandSource,
            localOnly: true,
            confirmation: confirmation,
            redaction: redaction,
            errorShape: .structuredActionErrorV1,
            timeoutSeconds: timeoutSeconds,
            retention: .localOnly
        )
    }
}
