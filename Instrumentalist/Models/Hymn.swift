import Foundation

/// The two playable renditions of a hymn that live in Azure Blob Storage.
enum HymnType: String, CaseIterable, Hashable {
    case piano
    case choir
}

/// A specific, downloadable hymn rendition: a number, a type, and a version.
///
/// Most hymns only have version 1. A curated set of hymns also ships a version 2
/// (see `HymnCatalog.secondVersionHymns`).
struct Hymn: Hashable, Identifiable {
    var number: Int
    var type: HymnType
    var version: Int = 1

    var id: String { fileName }

    /// The exact blob/file name for this rendition, e.g. `piano356-1.mp3`.
    /// This is the single key used for both the remote URL and the local cache.
    var fileName: String { AzureConfig.fileName(type: type, number: number, version: version) }

    /// The full remote URL in Azure Blob Storage.
    var remoteURL: URL { AzureConfig.url(type: type, number: number, version: version) }
}
