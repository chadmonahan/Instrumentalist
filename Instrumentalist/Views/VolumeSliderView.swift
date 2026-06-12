import SwiftUI
import MediaPlayer

/// Audio output indicator + volume slider, shown below the number pad. The
/// indicator lets the operator confirm at a glance that sound is going to the
/// PA (external output) and not the iPad's built-in speaker.
///
/// The slider controls the **system** volume (via MPVolumeView), so it is the
/// same control as the hardware volume buttons and stays in sync with them.
struct VolumeSliderView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 24) {
            outputIndicator
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.white.opacity(0.7))
                volumeSlider
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .font(.system(size: 24, weight: .semibold))
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .frame(height: 48)
    }

    @ViewBuilder
    private var volumeSlider: some View {
        #if targetEnvironment(simulator)
        // MPVolumeView doesn't render in the simulator — fall back to the app's
        // player volume there so the control stays demoable. Device builds get
        // the real system-volume slider below.
        @Bindable var audio = model.audio
        Slider(value: $audio.volume, in: 0...1)
            .tint(Theme.ready)
        #else
        SystemVolumeSlider()
            .frame(height: 34)
        #endif
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

/// The system-volume slider: an MPVolumeView bound to the device volume.
/// Moving it changes the iPad's volume; pressing the hardware buttons moves it.
private struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.tintColor = UIColor(Theme.ready)
        return view
    }

    func updateUIView(_ view: MPVolumeView, context: Context) {}
}
