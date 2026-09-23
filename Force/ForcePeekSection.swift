import SwiftUI
import ForceShared

/// Live Peek page: the switch, then the live calculation once it is on.
struct ForceLivePeekPage: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @ObservedObject var reader: ForcePeekReader
    @Binding var showingStage: Bool

    var body: some View {
        Form {
            Section {
                Toggle("Live Peek", isOn: $settings.livePeekEnabled)
            } footer: {
                Text("See the number the spectator types in the App Clip, live, without them pressing equals.")
            }
            if settings.livePeekEnabled {
                ForcePeekSection(reader: reader, showingStage: $showingStage)
            }
        }
        .navigationTitle("Live Peek")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Shows what the spectator is working through in the App Clip, live.
///
/// The calculation builds up as they type, so the performer sees `123 +` then `456 =`
/// then the answer, rather than only whichever number happens to be on screen.
struct ForcePeekSection: View {
    @ObservedObject var reader: ForcePeekReader
    @Binding var showingStage: Bool

    /// Performer-only preferences, so they stay local rather than syncing to the clip.
    @AppStorage("livePeekAutoHaptics") private var autoHaptics = false
    @AppStorage("livePeekAutoStage") private var autoStage = false

    var body: some View {
        Section {
            content
            controls
        } footer: {
            Text(footer)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch reader.state {
        case .value(let peek):
            transcript(peek)
        case .waiting, .idle:
            statusRow(icon: "ellipsis.circle", tint: .secondary, text: "Waiting for the spectator…")
        case .notAuthorized:
            statusRow(
                icon: "exclamationmark.triangle.fill",
                tint: .red,
                text: "This phone cannot read peeks for that code."
            )
        }
    }

    @ViewBuilder
    private var controls: some View {
        Toggle("Auto-Buzz New Numbers", isOn: $autoHaptics)
        Toggle("Auto-Open Big", isOn: $autoStage)
        Button {
            showingStage = true
        } label: {
            Label("Show Big", systemImage: "arrow.up.left.and.arrow.down.right")
        }
        if case .value = reader.state {
            Button(role: .destructive) {
                Task { await reader.clear() }
            } label: {
                Label("Clear", systemImage: "trash")
            }
        }
    }

    /// The calculation so far, oldest at the top so it reads in the order it was typed.
    /// The last line is what is on the spectator's screen right now, so it is the one
    /// given full size; the steps above it are context and stay quieter.
    private func transcript(_ peek: ForcePeekService.Peek) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(peek.entries) { entry in
                let isLatest = entry.id == peek.latest?.id
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.line)
                        .font(.system(
                            size: isLatest ? 34 : 19,
                            weight: isLatest ? .semibold : .regular,
                            design: .rounded
                        ))
                        .monospacedDigit()
                        .foregroundStyle(isLatest ? Color.primary : Color.secondary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Spacer()
                    if isLatest {
                        Text(entry.at.formatted(date: .omitted, time: .standard))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
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
        "The spectator's calculation appears here as they type it, no equals needed. "
            + "Show Big fills the screen — turn the phone sideways for the largest digits, "
            + "readable across a room. Clear wipes it before the next spectator."
    }
}
