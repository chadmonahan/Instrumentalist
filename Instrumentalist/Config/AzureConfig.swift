import Foundation

/// Single source of truth for how hymn files are named and located in Azure.
///
/// Verified live against the bucket:
///   - Piano:  `piano356-1.mp3`             (e.g. piano356-1 / piano151-2)
///   - Choir:  `H00356-1.mp3`               (H + 5-digit number + version; full
///             coverage for hymns 1–438, with `-2` for the second-tune hymns)
///
/// (Choir previously used a `chior{n}-{v}.mp3` pattern with patchy coverage; the
/// re-uploaded `H{NNNNN}-{v}.mp3` set replaces it and is complete.)
enum AzureConfig {
    /// Base URL; final files live directly under this path.
    static let baseURL = URL(string: "https://chadmonahan.blob.core.windows.net/hymns/hymns/")!

    /// e.g. `piano356-1.mp3`, `H00356-1.mp3`.
    static func fileName(type: HymnType, number: Int, version: Int = 1) -> String {
        switch type {
        case .piano: return "piano\(number)-\(version).mp3"
        case .choir: return String(format: "H%05d-%d.mp3", number, version)
        }
    }

    static func url(type: HymnType, number: Int, version: Int = 1) -> URL {
        baseURL.appendingPathComponent(fileName(type: type, number: number, version: version))
    }
}
