import SwiftUI

/// The single screen. For now both orientations use one stacked layout: the five
/// slot buttons across the top, then the now-playing area, number pad, and volume.
struct ContentView: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                SlotColumnView(axis: .horizontal)
                    .frame(height: min(max(geo.size.height * 0.14, 110), 150))
                NowPlayingView()
                NumberPadView()
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
