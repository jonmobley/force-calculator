import SwiftUI
import ForceShared

@main
struct ForceClipApp: App {
    /// Built-in defaults, never the app group.
    ///
    /// The clip runs on a spectator's device, where the performer's group container does
    /// not exist and never will, so reading it returned nothing and logged a CFPrefs
    /// error about containers on every launch. Everything real arrives from the
    /// invocation URL or the config service; the defaults only have to look like a
    /// calculator for the frame before they do.
    @StateObject private var settings = CalculatorSettings()

    /// Whose settings this clip is running for, and the one fetch of them. The clip has
    /// no stored identity of its own, because every performer owns their own record now
    /// rather than all of them sharing one.
    @StateObject private var session = ClipSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(session)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let url = userActivity.webpageURL else { return }
                    session.invoked(with: url, settings: settings)
                }
                .onOpenURL { url in
                    session.invoked(with: url, settings: settings)
                }
                .task {
                    await session.startWithoutInvocation(settings: settings)
                }
        }
    }
}

/// Which performer the running clip belongs to, shared down the view tree so live peek
/// reports land in the right record, plus the single fetch of that performer's settings.
///
/// A clip is normally launched by an invocation URL naming the performer, but the URL can
/// land after the first frame, and in a development launch it may not arrive at all. The
/// fetch therefore runs on whichever comes first: the invocation, or a short wait for one.
/// Tying it to the invocation alone left a clip that never heard one showing nothing but
/// built-in defaults, with live peek silently off.
@MainActor
final class ClipSession: ObservableObject {
    @Published private(set) var performerID = PerformerID.shared

    /// Long enough for an invocation already on its way to land, short enough that a
    /// spectator holding the phone is not looking at the wrong number while it passes.
    private static let invocationGrace: TimeInterval = 0.5

    private var hasFetched = false
    private var hasInvocation = false

    /// The normal path. An invocation always wins, even over a fallback that already ran,
    /// because the fallback can only ever have guessed the shared record.
    func invoked(with url: URL, settings: CalculatorSettings) {
        guard !hasInvocation else { return }
        hasInvocation = true
        hasFetched = true
        // Stickers written before the config service carry the settings themselves;
        // newer ones carry only the id and the settings come from the service.
        AppClipQuery.apply(url, to: settings)
        performerID = AppClipQuery.performerID(in: url)
        Task { await fetch(into: settings) }
    }

    /// The safety net, for a launch where no invocation ever arrives.
    func startWithoutInvocation(settings: CalculatorSettings) async {
        try? await Task.sleep(for: .seconds(Self.invocationGrace))
        guard !hasFetched else { return }
        hasFetched = true
        debugLog("ℹ️ No invocation arrived, falling back to \(performerID)")
        await fetch(into: settings)
    }

    /// On failure the clip keeps whatever it already has, so an older sticker still
    /// performs correctly without a network round trip.
    private func fetch(into settings: CalculatorSettings) async {
        do {
            let live = try await ForceConfigService.fetch(id: performerID)
            settings.applyStored(live)
            debugLog("☁️ Applied live settings for \(performerID): "
                + "forceNumber=\(settings.forceNumber) peek=\(settings.livePeekEnabled)")
        } catch {
            debugLog("ℹ️ Live settings unavailable for \(performerID): \(error)")
        }
    }
}
