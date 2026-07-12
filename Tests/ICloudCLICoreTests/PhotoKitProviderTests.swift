import Foundation
import Testing
@testable import ICloudCLICore

@Test func photoKitProviderReturnsEvidenceBackedFactsWithoutMediaRequests() throws {
    let client = FakePhotoKitClient(
        authorization: .authorized,
        assets: [PhotoKitAssetFact(id: "asset-1", filename: "IMG_0001.HEIC", mediaType: "image", createdAt: Date(timeIntervalSince1970: 10), modifiedAt: nil, pixelWidth: 4032, pixelHeight: 3024, isFavorite: true, isHidden: false, albumNames: ["Favorites"], availability: .unknown)]
    )
    let rows = try PhotoKitProvider(client: client).assets(limit: 10)
    #expect(rows.first?.id == "asset-1")
    #expect(rows.first?.provenance.source == "photokit")
    #expect(rows.first?.facts.albumNames == ["Favorites"])
    #expect(rows.first?.observations.isEmpty == true)
    #expect(client.requestedMedia == false)
}

@Test func photoKitAuthorizationProbeNeverPrompts() {
    let client = FakePhotoKitClient(authorization: .notDetermined, assets: [])
    let report = PhotoKitProvider(client: client).authorization()
    #expect(report.requestsAccess == false)
    #expect(report.canRead == false)
    #expect(client.requestedAuthorization == false)
}

@Test func photosPrivateFallbackRequiresExplicitFlag() throws {
    let command = try CLIParser().parse(arguments: ["icloud-cli", "photos", "list", "--degraded-filesystem", "--photos-library", "/tmp/Photos.photoslibrary"])
    guard case .photosList(let options) = command else { Issue.record("Expected photos list"); return }
    #expect(options.degradedFilesystem)
    #expect(try CLIParser().parse(arguments: ["icloud-cli", "photos", "authorization"]) == .photosAuthorization(.json))
}

@Test func permissionsDoctorUsesPhotoKitAuthorizationInsteadOfFilesystemProbe() {
    let probe = PermissionsDoctor(photoAuthorization: .denied).diagnose().first { $0.command == "photos list" }
    #expect(probe?.status == "photokit-denied")
    #expect(probe?.paths.isEmpty == true)
}

private final class FakePhotoKitClient: PhotoKitClient, @unchecked Sendable {
    let authorization: PhotoKitAuthorizationState
    let storedAssets: [PhotoKitAssetFact]
    var requestedAuthorization = false
    var requestedMedia = false

    init(authorization: PhotoKitAuthorizationState, assets: [PhotoKitAssetFact]) {
        self.authorization = authorization
        self.storedAssets = assets
    }

    func authorizationState() -> PhotoKitAuthorizationState { authorization }
    func fetchAssets(limit: Int) throws -> [PhotoKitAssetFact] { Array(storedAssets.prefix(limit)) }
}
