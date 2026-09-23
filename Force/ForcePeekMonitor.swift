import SwiftUI
import ForceShared

/// Keeps live-peek reactions running from the home screen.
///
/// Auto-buzz and the big display have to fire while the performer is looking at
/// the list, not only after they open the Live Peek page. The page owns the
/// switches; this view reads the same stored preferences and presents the stage.
struct ForcePeekMonitor: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @ObservedObject var reader: ForcePeekReader
    @Binding var showingStage: Bool

    @AppStorage("livePeekAutoHaptics") private var autoHaptics = false
    @AppStorage("livePeekAutoStage") private var autoStage = false
    @StateObject private var haptics = PeekHaptics()
    @State private var lastAutoPlayed: String?
    @State private var lastAutoStaged: String?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: reader.state) { _, newState in
                guard settings.livePeekEnabled else { return }
                handleStateChange(newState)
            }
            .onChange(of: settings.livePeekEnabled) { _, enabled in
                if !enabled { reset() }
            }
            .onDisappear { haptics.cancel() }
    }

    /// Buzzes and/or opens the big display the first time a value settles, and
    /// rearms both once the readout goes quiet so the next arrival is fresh.
    private func handleStateChange(_ state: ForcePeekReader.State) {
        guard case .value(let peek) = state, let latest = peek.latest else {
            clearMemory()
            return
        }
        if autoHaptics, latest.value != lastAutoPlayed {
            lastAutoPlayed = latest.value
            haptics.play(latest.value)
        }
        if autoStage, !showingStage, latest.value != lastAutoStaged {
            lastAutoStaged = latest.value
            showingStage = true
        }
    }

    /// Forgets the last arrival without cutting off a buzz already in the hand.
    private func clearMemory() {
        lastAutoPlayed = nil
        lastAutoStaged = nil
    }

    private func reset() {
        clearMemory()
        haptics.cancel()
    }
}
