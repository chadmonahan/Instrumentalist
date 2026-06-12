import SwiftUI

/// The single screen. Five slot buttons across the top, then two columns:
/// player (big number + progress + transport) on the left, number pad on the
/// right. Output status + volume span the bottom.
struct ContentView: View {
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
    }
}

#Preview("Landscape", traits: .landscapeLeft) {
    ContentView().environment(AppModel())
}

#Preview("Portrait") {
    ContentView().environment(AppModel())
}
