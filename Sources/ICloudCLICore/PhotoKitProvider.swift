import Foundation
import Photos

public enum PhotoKitAuthorizationState: String, Codable, Sendable { case notDetermined = "not-determined", restricted, denied, limited, authorized, unknown }
public enum PhotoAvailability: String, Codable, Sendable { case local, cloud, unknown }

public struct PhotoKitAssetFact: Equatable, Sendable {
    public let id: String
    public let filename: String?
    public let mediaType: String
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let isFavorite: Bool
    public let isHidden: Bool
    public let albumNames: [String]
    public let availability: PhotoAvailability

    public init(id: String, filename: String?, mediaType: String, createdAt: Date?, modifiedAt: Date?, pixelWidth: Int, pixelHeight: Int, isFavorite: Bool, isHidden: Bool, albumNames: [String], availability: PhotoAvailability) {
        self.id = id; self.filename = filename; self.mediaType = mediaType; self.createdAt = createdAt; self.modifiedAt = modifiedAt; self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight; self.isFavorite = isFavorite; self.isHidden = isHidden; self.albumNames = albumNames; self.availability = availability
    }
}

public struct PhotoEvidenceAsset: Codable, Equatable, Sendable {
    public struct Facts: Codable, Equatable, Sendable {
        public let filename: String?
        public let mediaType: String
        public let createdAt: Date?
        public let modifiedAt: Date?
        public let pixelWidth: Int
        public let pixelHeight: Int
        public let isFavorite: Bool
        public let isHidden: Bool
        public let albumNames: [String]
        public let availability: PhotoAvailability
    }
    public struct Provenance: Codable, Equatable, Sendable {
        public let source: String; public let degraded: Bool
        public init(source: String, degraded: Bool) { self.source = source; self.degraded = degraded }
    }
    public let id: String
    public let facts: Facts
    public let observations: [String]
    public let provenance: Provenance
    public init(id: String, facts: Facts, observations: [String], provenance: Provenance) { self.id = id; self.facts = facts; self.observations = observations; self.provenance = provenance }
}

public struct PhotoKitAuthorizationReport: Codable, Equatable, Sendable {
    public let provider: String
    public let state: PhotoKitAuthorizationState
    public let canRead: Bool
    public let requestsAccess: Bool
    public let nextAction: String?
    public let limitations: [String]
    public init(state: PhotoKitAuthorizationState, canRead: Bool, nextAction: String?, limitations: [String]) { self.provider = "photokit"; self.state = state; self.canRead = canRead; self.requestsAccess = false; self.nextAction = nextAction; self.limitations = limitations }
}

public protocol PhotoKitClient: Sendable {
    func authorizationState() -> PhotoKitAuthorizationState
    func fetchAssets(limit: Int) throws -> [PhotoKitAssetFact]
}

public enum PhotoKitProviderError: Error, LocalizedError {
    case authorization(PhotoKitAuthorizationState)
    public var errorDescription: String? {
        switch self { case .authorization(let state): return "Photos authorization is \(state.rawValue). Check with `photos authorization`; no access prompt was requested." }
    }
}

public struct PhotoKitProvider: Sendable {
    public let client: any PhotoKitClient
    public init(client: any PhotoKitClient = SystemPhotoKitClient()) { self.client = client }

    public func authorization() -> PhotoKitAuthorizationReport {
        let state = client.authorizationState()
        let canRead = state == .authorized || state == .limited
        return PhotoKitAuthorizationReport(state: state, canRead: canRead, nextAction: canRead ? nil : "Grant Photos access in System Settings > Privacy & Security > Photos.", limitations: ["PhotoKit does not reliably expose local-versus-cloud availability without requesting media.", "No pixels, thumbnails, OCR, or classification are requested."])
    }

    public func assets(limit: Int) throws -> [PhotoEvidenceAsset] {
        let state = client.authorizationState()
        guard state == .authorized || state == .limited else { throw PhotoKitProviderError.authorization(state) }
        return try client.fetchAssets(limit: min(max(limit, 1), 10_000)).map { fact in
            PhotoEvidenceAsset(id: fact.id, facts: .init(filename: fact.filename, mediaType: fact.mediaType, createdAt: fact.createdAt, modifiedAt: fact.modifiedAt, pixelWidth: fact.pixelWidth, pixelHeight: fact.pixelHeight, isFavorite: fact.isFavorite, isHidden: fact.isHidden, albumNames: fact.albumNames.sorted(), availability: fact.availability), observations: [], provenance: .init(source: "photokit", degraded: false))
        }
    }
}

public struct SystemPhotoKitClient: PhotoKitClient {
    public init() {}
    public func authorizationState() -> PhotoKitAuthorizationState {
        Self.authorizationState()
    }
    public static func authorizationState() -> PhotoKitAuthorizationState {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .limited: .limited
        case .authorized: .authorized
        @unknown default: .unknown
        }
    }

    public func fetchAssets(limit: Int) throws -> [PhotoKitAssetFact] {
        let options = PHFetchOptions()
        options.fetchLimit = limit
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        var rows: [PhotoKitAssetFact] = []
        result.enumerateObjects { asset, _, _ in
            let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename
            let type = switch asset.mediaType { case .image: "image"; case .video: "video"; case .audio: "audio"; default: "unknown" }
            var albumNames: [String] = []
            PHAssetCollection.fetchAssetCollectionsContaining(asset, with: .album, options: nil).enumerateObjects { collection, _, _ in
                if let title = collection.localizedTitle { albumNames.append(title) }
            }
            rows.append(.init(id: asset.localIdentifier, filename: filename, mediaType: type, createdAt: asset.creationDate, modifiedAt: asset.modificationDate, pixelWidth: asset.pixelWidth, pixelHeight: asset.pixelHeight, isFavorite: asset.isFavorite, isHidden: asset.isHidden, albumNames: albumNames, availability: .unknown))
        }
        return rows
    }
}
