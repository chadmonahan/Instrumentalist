import SwiftUI

@main
struct InstrumentalistApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .background(Theme.background.ignoresSafeArea())
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
                .preferredColorScheme(.dark)
                // Screen-sleep is now managed by AppModel: it forces the screen
                // awake during use and lets the iPad sleep after ~60 min idle.
        }
    }
}
