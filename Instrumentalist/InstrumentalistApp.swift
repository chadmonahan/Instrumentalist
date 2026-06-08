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
                .onAppear {
                    // Kiosk: never let the screen sleep during a service.
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
