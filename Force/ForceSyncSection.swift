import SwiftUI
import ForceShared

/// One-line report on whether the config service matches the app.
///
/// Collapsed by default because it needs no attention once a token is saved. It
/// expands to allow entering or replacing the token, and shouts when the service
/// is behind, since that silently means spectators would see old settings.
struct ForceSyncSection: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @ObservedObject var publisher: ForceConfigPublisher

    @State private var isExpanded = false
    @State private var token = ""

    private var needsAttention: Bool {
        switch publisher.state {
        case .outOfDate, .missingToken: return true
        case .publishing, .synced: return false
        }
    }

    var body: some View {
        Section {
            statusRow
            if isExpanded {
                tokenField
                Button("Publish Now") { publisher.publish() }
                    .disabled(publisher.state == .publishing)
            }
        } footer: {
            if needsAttention {
                Text(attentionFooter)
                    .foregroundColor(.red)
            }
        }
    }

    private var statusRow: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(tint)
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
                publisher.publish()
            }
            .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Presentation

    private var label: String {
        switch publisher.state {
        case .missingToken:
            return "Not publishing"
        case .publishing:
            return "Publishing…"
        case .synced(let date):
            return "Live · \(date.formatted(date: .omitted, time: .shortened))"
        case .outOfDate(let reason):
            return "Out of date · \(reason)"
        }
    }

    private var icon: String {
        switch publisher.state {
        case .missingToken: return "circle.dashed"
        case .publishing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.circle.fill"
        case .outOfDate: return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch publisher.state {
        case .missingToken: return .secondary
        case .publishing: return .secondary
        case .synced: return .green
        case .outOfDate: return .red
        }
    }

    private var attentionFooter: String {
        switch publisher.state {
        case .outOfDate:
            return "Spectators will see your previous settings. This retries "
                + "automatically as soon as you are back online."
        case .missingToken:
            return "Tap above and add your write token so stickers pick up "
                + "setting changes."
        case .publishing, .synced:
            return ""
        }
    }
}
