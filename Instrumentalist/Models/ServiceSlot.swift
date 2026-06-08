import Foundation

/// The five fixed slots in a Sunday-morning service line-up. These are the five
/// large buttons down the left (landscape) / across the top (portrait).
enum ServiceSlot: String, CaseIterable, Identifiable {
    case prelude
    case opening
    case memorial
    case closing
    case postlude

    var id: String { rawValue }

    /// Button title.
    var title: String {
        switch self {
        case .prelude:  return "Prelude"
        case .opening:  return "Opening"
        case .memorial: return "Memorial"
        case .closing:  return "Closing"
        case .postlude: return "Postlude"
        }
    }

    /// The three user-programmable hymn slots. Prelude is derived from these
    /// (piano renditions, in order); postlude is a bundled rotation clip.
    static let programmable: [ServiceSlot] = [.opening, .memorial, .closing]

    var isProgrammable: Bool { ServiceSlot.programmable.contains(self) }

    /// The rendition played when this slot is the current selection.
    /// Opening/Memorial/Closing play the choir version; prelude/postlude are special.
    var mainType: HymnType { .choir }
}
