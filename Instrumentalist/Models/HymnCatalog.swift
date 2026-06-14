import Foundation

/// Static facts about the hymn collection that the app needs but can't derive
/// from a file name alone.
enum HymnCatalog {
    /// Acceptable hymn numbers that can be keyed on the pad. Generous bounds —
    /// a number that doesn't exist in storage simply fails to download and shows red.
    static let numberRange = 1...999

    /// Hymns that also have a `-2.mp3` "second tune" in storage. When a number
    /// here is keyed, the pad exposes a `1st / 2nd` toggle. Just add the number to
    /// this list to enable the toggle for that hymn.
    static let secondVersionHymns: Set<Int> = [
        151, // piano + chior -1/-2 in Azure
        436, // piano + chior -1/-2 in Azure
    ]

    static func hasSecondVersion(_ number: Int) -> Bool {
        secondVersionHymns.contains(number)
    }

    static func isValid(_ number: Int) -> Bool {
        numberRange.contains(number)
    }
}
