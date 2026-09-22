import SwiftUI
import ForceShared

@main
struct ForceClipApp: App {
    @StateObject private var settings: CalculatorSettings = {
        let stored = CalculatorSettings()
        stored.loadSettings()
        return stored
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let url = userActivity.webpageURL else { return }
                    AppClipQuery.apply(url, to: settings)
                }
                .onOpenURL { url in
                    AppClipQuery.apply(url, to: settings)
                }
        }
    }
}
