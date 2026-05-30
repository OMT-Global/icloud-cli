import Foundation

public struct SafariProfileDirectoryResolver: Sendable {
    public init() {}

    public func directory(baseDirectory: URL, profile: String?) -> URL {
        guard let profile = profile?.trimmingCharacters(in: .whitespacesAndNewlines), !profile.isEmpty else {
            return baseDirectory
        }
        guard profile.lowercased() != "all" else {
            return baseDirectory
        }

        let candidates = candidateDirectories(baseDirectory: baseDirectory, profile: profile)
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) } ?? candidates[0]
    }

    private func candidateDirectories(baseDirectory: URL, profile: String) -> [URL] {
        let slug = profileSlug(profile)
        var candidates = [
            baseDirectory.appendingPathComponent("Profiles").appendingPathComponent(profile),
            baseDirectory.appendingPathComponent(profile),
        ]
        if slug != profile {
            candidates.append(baseDirectory.appendingPathComponent("Profiles").appendingPathComponent(slug))
            candidates.append(baseDirectory.appendingPathComponent(slug))
        }
        return candidates
    }

    private func profileSlug(_ profile: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return profile.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : "-"
        }.joined()
    }
}
