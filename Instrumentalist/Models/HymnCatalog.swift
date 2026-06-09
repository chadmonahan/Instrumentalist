import Foundation

/// Static facts about the hymn collection that the app needs but can't derive
/// from a file name alone.
enum HymnCatalog {
    /// Acceptable hymn numbers that can be keyed on the pad. Generous bounds —
    /// a number that doesn't exist in storage simply fails to download and shows red.
    static let numberRange = 1...999

    /// Hymns that also have a `-2.mp3` "second tune" in storage. When a number
    /// here is keyed, the pad exposes a `1st / 2nd` toggle. Extend as more are found.
    /// (Verified in Azure: 151 has piano/chior -1 and -2.)
    static let secondVersionHymns: Set<Int> = [
        151,
    ]

    static func hasSecondVersion(_ number: Int) -> Bool {
        secondVersionHymns.contains(number)
    }

    static func isValid(_ number: Int) -> Bool {
        numberRange.contains(number)
    }
}
