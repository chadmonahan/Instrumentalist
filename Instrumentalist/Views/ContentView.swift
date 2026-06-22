import SwiftUI

/// The single screen. Five slot buttons across the top, then two columns:
/// player (big number + progress + transport) on the left, number pad on the
/// right. Output status + volume span the bottom.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                SlotColumnView(axis: .horizontal)
                    .frame(height: min(max(geo.size.height * 0.14, 110), 150))
                HStack(spacing: 24) {
                    NowPlayingView()
                        .frame(maxWidth: .infinity)
                    NumberPadView()
                        .frame(maxWidth: .infinity)
                }
                VolumeSliderView()
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
        }
        .ignoresSafeArea(.keyboard)
        // Keep the screen awake on interaction. Every control already calls
        // registerActivity() in its action; this tap backstop catches taps on
        // empty space too. (A zero-distance DragGesture spanning the whole screen
        // used to live here, but it shadowed the buttons/slider and fired on every
        // touch-move — a likely cause of the first-launch unresponsiveness.)
        .simultaneousGesture(
            TapGesture().onEnded { model.registerActivity() }
        )
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    ContentView().environment(AppModel())
}

#Preview("Portrait") {
    ContentView().environment(AppModel())
}
