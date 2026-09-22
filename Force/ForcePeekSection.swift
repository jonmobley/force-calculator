import SwiftUI
import ForceShared

/// Shows the number the spectator is typing into the App Clip, live.
///
/// Only present while live peek is enabled. The value updates as the spectator
/// types, so the performer can read it at a glance without the spectator ever
/// pressing equals.
struct ForcePeekSection: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @ObservedObject var reader: ForcePeekReader
    @StateObject private var haptics = PeekHaptics()

    /// Performer-only preferences, so they stay local rather than syncing to the clip.
    @AppStorage("livePeekAutoHaptics") private var autoHaptics = false
    @State private var lastAutoPlayed: String?
    @State private var showingStage = false

    var body: some View {
        if settings.livePeekEnabled {
            Section {
                content
                controls
            } header: {
                Text("Live Peek")
            } footer: {
                Text(footer)
            }
            .onDisappear { haptics.cancel() }
            .onChange(of: reader.state) { _, newState in autoPlay(newState) }
            .fullScreenCover(isPresented: $showingStage) {
                PeekStageView(reader: reader)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch reader.state {
        case .value(let peek):
            valueRow(peek)
            tapOutButton(for: peek)
        case .waiting, .idle:
            statusRow(icon: "ellipsis.circle", tint: .secondary, text: "Waiting for the spectator…")
        case .missingToken:
            statusRow(
                icon: "exclamationmark.triangle.fill",
                tint: .red,
                text: "Add your write token in Sync to receive peeks."
            )
        }
    }

    @ViewBuilder
    private var controls: some View {
        Toggle("Auto-Buzz New Numbers", isOn: $autoHaptics)
        Button {
            showingStage = true
        } label: {
            Label("Show Big", systemImage: "arrow.up.left.and.arrow.down.right")
        }
    }

    private func valueRow(_ peek: ForcePeekService.Peek) -> some View {
        HStack {
            Text(peek.value)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer()
            Text(peek.updatedAt.formatted(date: .omitted, time: .standard))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func tapOutButton(for peek: ForcePeekService.Peek) -> some View {
        Button {
            haptics.play(peek.value)
        } label: {
            Label("Tap Out Digits", systemImage: "hand.tap.fill")
        }
    }

    private func statusRow(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(tint)
            Text(text)
                .foregroundColor(.secondary)
        }
    }

    private var footer: String {
        "The spectator's number appears here as they type it, no equals needed. "
            + "Tap Out Digits buzzes it in your hand; Auto-Buzz does it for each new "
            + "number; Show Big fills the screen so you can read it from across a room."
    }

    /// Buzzes a value the first time it settles, so a value the spectator leaves
    /// sitting is felt once rather than on every poll.
    private func autoPlay(_ state: ForcePeekReader.State) {
        guard autoHaptics, case .value(let peek) = state else { return }
        guard peek.value != lastAutoPlayed else { return }
        lastAutoPlayed = peek.value
        haptics.play(peek.value)
    }
}
