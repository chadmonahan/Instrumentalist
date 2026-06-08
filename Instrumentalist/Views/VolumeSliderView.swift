import SwiftUI

/// App playback-volume slider, shown below the number pad. Controls the player's
/// volume relative to the device's system volume.
struct VolumeSliderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var audio = model.audio
        HStack(spacing: 16) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.white.opacity(0.7))
            Slider(value: $audio.volume, in: 0...1)
                .tint(Theme.ready)
            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.white.opacity(0.7))
        }
        .font(.system(size: 24, weight: .semibold))
        .padding(.horizontal, 8)
        .frame(height: 44)
    }
}
