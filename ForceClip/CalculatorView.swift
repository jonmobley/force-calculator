import SwiftUI
import ForceShared

/// Clip wrapper around the shared calculator. The keys, layout, mode switching, and
/// motion sensor all live in `CalculatorViewRoot`; the clip's own concerns are the
/// peek reporter it feeds and the `ClipSession` context it runs inside.
struct CalculatorView: View {
    @EnvironmentObject var settings: CalculatorSettings
    @EnvironmentObject var session: ClipSession

    /// Owned by the clip so its identity survives the invocation URL landing after the
    /// calculator is already up. Reset on close through `CalculatorSession.onDisappear`.
    @StateObject private var peek = PeekReporter()

    var body: some View {
        CalculatorViewRoot(
            settings: settings,
            peekReporter: peek,
            demoRequested: session.wantsPeekDemo
        )
        // The invocation URL can arrive after the calculator is already up, so the
        // reporter has to learn whose record to write to once it does.
        .onChange(of: session.performerID) { _, id in
            peek.performerID = id
        }
        // Peek is re-fetched on the same schedule the clip session uses for live
        // settings, so the switch here matches what the performer has just toggled.
        .onAppear {
            peek.performerID = session.performerID
            session.watchPeek(settings)
        }
        .onDisappear { session.stopWatchingPeek() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.watchPeek(settings)
            } else {
                session.stopWatchingPeek()
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
}
