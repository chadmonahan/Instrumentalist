import Foundation

/// Static facts about the hymn collection that the app needs but can't derive
/// from a file name alone.
enum HymnCatalog {
    /// Valid hymn numbers. The hymnal runs 1–438.
    static let numberRange = 1...438

    /// Whether `digits` could still become a valid hymn number — i.e. it's the
    /// start of some number in `numberRange`, with no leading zero. Used to ignore
    /// keypad presses that can't lead anywhere valid (e.g. a leading 0, "439", or a
    /// 3rd digit after "44"). Note: any allowed buffer is itself already valid,
    /// since 1…438 is contiguous.
    static func isEnterablePrefix(_ digits: String) -> Bool {
        guard let first = digits.first, first != "0",
              digits.count <= String(numberRange.upperBound).count else { return false }
        return numberRange.contains { String($0).hasPrefix(digits) }
    }

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
