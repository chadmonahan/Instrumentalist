import Foundation

/// Static facts about the hymn collection that the app needs but can't derive
/// from a file name alone.
enum HymnCatalog {
    /// Acceptable hymn numbers that can be keyed on the pad. Generous bounds —
    /// a number that doesn't exist in storage simply fails to download and shows red.
    static let numberRange = 1...999

    /// Hymns that also have a `-2.mp3` second rendition in storage.
    ///
    /// Empty for now. Chad will provide the real list; once populated, the UI
    /// automatically exposes a `1 / 2` version toggle for those numbers.
    static let secondVersionHymns: Set<Int> = []

    static func hasSecondVersion(_ number: Int) -> Bool {
        secondVersionHymns.contains(number)
    }

    static func isValid(_ number: Int) -> Bool {
        numberRange.contains(number)
    }
}
