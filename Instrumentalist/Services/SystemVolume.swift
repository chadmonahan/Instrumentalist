import MediaPlayer
import UIKit

/// Programmatic system-volume control. iOS has no public setter for the system
/// volume; the standard approach is driving the UISlider inside an offscreen
/// MPVolumeView. No-op in the simulator (MPVolumeView is inert there — the app
/// falls back to player volume instead; see AppModel.applyVolumePreset).
@MainActor
enum SystemVolume {
    private static let volumeView = MPVolumeView(frame: .zero)

    /// Set the device volume, 0...1.
    static func set(_ value: Float) {
        let slider = volumeView.subviews.compactMap { $0 as? UISlider }.first
        // The slider needs a runloop beat before it accepts a programmatic value.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            slider?.value = min(1, max(0, value))
        }
    }
}
