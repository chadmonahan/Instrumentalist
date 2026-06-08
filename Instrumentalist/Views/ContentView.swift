import SwiftUI

/// The single screen. Adapts between landscape (slots down the left, number pad
/// with the now-playing area on the right) and portrait (slots across the top,
/// now-playing and pad stacked below).
struct ContentView: View {
    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height

            Group {
                if landscape {
                    HStack(spacing: 16) {
                        SlotColumnView(axis: .vertical)
                            .frame(width: min(max(geo.size.width * 0.22, 200), 280))
                        VStack(spacing: 16) {
                            NowPlayingView()
                            NumberPadView()
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        SlotColumnView(axis: .horizontal)
                            .frame(height: min(max(geo.size.height * 0.14, 110), 150))
                        NowPlayingView()
                        NumberPadView()
                    }
                }
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
