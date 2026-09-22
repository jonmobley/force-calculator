import SwiftUI
import ForceShared

/// Controls for the config service that feeds settings to the App Clip.
///
/// Without a write token the app works exactly as before, embedding settings in
/// each newly written tag. With a token, settings are published instead, so tags
/// already in circulation pick up changes.
struct ForceSyncSection: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @ObservedObject var publisher: ForceConfigPublisher

    @State private var token = ""
    @State private var isEditingToken = false

    var body: some View {
        Section {
            if isEditingToken || ConfigTokenStore.load() == nil {
                tokenField
            } else {
                storedTokenRow
            }
            statusRow
            publishButton
        } header: {
            Text("Live Settings")
        } footer: {
            Text(
                "With a write token, your settings are published so NFC stickers "
                + "and QR codes you already made stay up to date. Without one, "
                + "each sticker keeps the settings it was written with."
            )
        }
    }

    private var tokenField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("Write token", text: $token)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Save Token") {
                ConfigTokenStore.save(token)
                token = ""
                isEditingToken = false
                publisher.publish(settings)
            }
            .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var storedTokenRow: some View {
        HStack {
            Text("Write Token")
            Spacer()
            Text("Saved")
                .foregroundColor(.secondary)
            Button("Change") { isEditingToken = true }
                .buttonStyle(.borderless)
        }
    }

    private var statusRow: some View {
        HStack {
            Text("Status")
            Spacer()
            Text(statusText)
                .font(.caption)
                .multilineTextAlignment(.trailing)
                .foregroundColor(statusColor)
        }
    }

    private var publishButton: some View {
        Button("Publish Now") { publisher.publish(settings) }
            .disabled(publisher.state == .publishing)
    }

    private var statusText: String {
        switch publisher.state {
        case .idle:
            return "Not published yet"
        case .missingToken:
            return "Add a write token to publish"
        case .publishing:
            return "Publishing…"
        case .published(let date):
            return "Published \(date.formatted(date: .omitted, time: .shortened))"
        case .failed(let message):
            return message
        }
    }

    private var statusColor: Color {
        switch publisher.state {
        case .failed:
            return .red
        case .published:
            return .green
        default:
            return .secondary
        }
    }
}
