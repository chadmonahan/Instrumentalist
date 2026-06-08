import SwiftUI

/// Kiosk color language: black background, button colors reflect state.
enum Theme {
    static let background = Color.black

    static let ready    = Color(red: 0.18, green: 0.72, blue: 0.35) // green
    static let unset    = Color(red: 0.80, green: 0.18, blue: 0.18) // red
    static let editing  = Color(red: 0.92, green: 0.78, blue: 0.18) // yellow

    static let idleFill = Color(white: 0.16)
    static let activeRing = Color.white

    static func color(for state: ControlState) -> Color {
        switch state {
        case .unset:                   return unset
        case .editing, .downloading:   return editing
        case .ready:                   return ready
        }
    }

    /// Text color that reads well on a given state fill.
    static func textColor(for state: ControlState) -> Color {
        switch state {
        case .editing, .downloading: return .black
        default:                     return .white
        }
    }
}
