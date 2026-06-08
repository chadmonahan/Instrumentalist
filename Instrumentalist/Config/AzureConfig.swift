import Foundation

/// Single source of truth for how hymn files are named and located in Azure.
///
/// Verified live against the bucket on 2026-06-08:
///   - piano356-1.mp3  -> 200
///   - chior356-1.mp3  -> 200   (the blob name really is spelled "chior" — do not "fix" to "choir")
///   - choir356-1.mp3  -> 404
enum AzureConfig {
    /// Base URL; final files live directly under this path.
    static let baseURL = URL(string: "https://chadmonahan.blob.core.windows.net/hymns/hymns/")!

    /// Filename prefix per rendition. NOTE the intentional "chior" spelling — that is
    /// the actual blob name in storage, confirmed by a live HEAD request.
    static func prefix(for type: HymnType) -> String {
        switch type {
        case .piano: return "piano"
        case .choir: return "chior"
        }
    }

    /// e.g. `piano356-1.mp3`, `chior356-1.mp3`.
    static func fileName(type: HymnType, number: Int, version: Int = 1) -> String {
        "\(prefix(for: type))\(number)-\(version).mp3"
    }

    static func url(type: HymnType, number: Int, version: Int = 1) -> URL {
        baseURL.appendingPathComponent(fileName(type: type, number: number, version: version))
    }
}
