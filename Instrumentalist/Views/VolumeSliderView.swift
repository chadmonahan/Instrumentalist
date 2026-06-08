import SwiftUI

/// Audio output indicator + app playback-volume slider, shown below the number
/// pad. The indicator lets the operator confirm at a glance that sound is going
/// to the PA (external output) and not the iPad's built-in speaker.
struct VolumeSliderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var audio = model.audio
        HStack(spacing: 24) {
            outputIndicator
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.white.opacity(0.7))
                Slider(value: $audio.volume, in: 0...1)
                    .tint(Theme.ready)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .font(.system(size: 24, weight: .semibold))
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
    }

    private var outputIndicator: some View {
        let external = model.audio.isExternalOutput
        return HStack(spacing: 8) {
            Image(systemName: external ? "cable.connector" : "ipad.gen2")
            Text(external ? "Output: \(model.audio.outputRouteName)"
                          : "iPad speaker — not on PA")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(external ? Theme.ready : Theme.editing)
    }
}
