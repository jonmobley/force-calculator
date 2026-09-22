import SwiftUI
import ForceShared

@main
struct ForceClipApp: App {
    @StateObject private var settings: CalculatorSettings = {
        let stored = CalculatorSettings()
        stored.loadSettings()
        return stored
    }()

    /// Set once live settings arrive, so stale parameters on an older sticker
    /// cannot overwrite them if the invocation is delivered afterwards.
    @State private var usingLiveSettings = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let url = userActivity.webpageURL else { return }
                    applyInvocation(url)
                }
                .onOpenURL { url in
                    applyInvocation(url)
                }
                .task {
                    await loadLiveSettings()
                }
        }
    }

    /// Applies the settings embedded in older stickers. Newer stickers carry no
    /// settings, so this is a no-op for them.
    private func applyInvocation(_ url: URL) {
        guard !usingLiveSettings else { return }
        AppClipQuery.apply(url, to: settings)
    }

    /// Fetches the performer's current settings.
    ///
    /// On failure the clip keeps whatever the invocation URL supplied, so an
    /// older sticker still performs correctly without a network round trip.
    private func loadLiveSettings() async {
        do {
            let live = try await ForceConfigService.fetch()
            settings.applyStored(live)
            usingLiveSettings = true
            debugLog("☁️ Applied live settings: forceNumber=\(settings.forceNumber)")
        } catch {
            debugLog("ℹ️ Live settings unavailable, using invocation URL: \(error)")
        }
    }
}
