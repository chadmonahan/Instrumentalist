import Foundation

/// Static facts about the hymn collection that the app needs but can't derive
/// from a file name alone.
enum HymnCatalog {
    /// Acceptable hymn numbers that can be keyed on the pad. Generous bounds —
    /// a number that doesn't exist in storage simply fails to download and shows red.
    static let numberRange = 1...999

    /// Hymns that also have a `-2.mp3` "second tune". When a number here is keyed,
    /// the pad exposes a `1st / 2nd` toggle. Just add the number to enable it.
    ///
    /// Verified in Azure: each has both piano `-1`/`-2` AND choir `-1`/`-2`
    /// (choir uses the `H{NNNNN}-{v}.mp3` pattern; see AzureConfig).
    static let secondVersionHymns: Set<Int> = [
        95, 113, 151, 163, 170, 183, 222, 227, 240, 273,
        285, 290, 299, 309, 327, 345, 355, 389, 435, 436,
    ]

    static func hasSecondVersion(_ number: Int) -> Bool {
        secondVersionHymns.contains(number)
    }

    static func isValid(_ number: Int) -> Bool {
        numberRange.contains(number)
    }
}
