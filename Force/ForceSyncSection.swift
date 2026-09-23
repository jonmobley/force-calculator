import SwiftUI

/// Whether the config service matches the app.
///
/// The app publishes under credentials it generates for itself, so there is
/// nothing to set up. This page is for checking that, and for sending again
/// when the service has fallen behind.
struct ForceSyncPage: View {
    @ObservedObject var publisher: ForceConfigPublisher

    private var needsAttention: Bool {
        switch publisher.state {
        case .outOfDate: return true
        case .idle, .publishing, .synced: return false
        }
    }

    var body: some View {
        Form {
            Section {
                statusRow
                Button("Publish Now") { publisher.publish() }
                    .disabled(publisher.state == .publishing)
            } footer: {
                Text(footer)
                    .foregroundStyle(needsAttention ? Color.red : Color.secondary)
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(label)
        }
    }

    // MARK: - Presentation

    private var label: String {
        switch publisher.state {
        case .idle:
            return "Not published yet"
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
        case .idle: return "circle.dashed"
        case .publishing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.circle.fill"
        case .outOfDate: return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch publisher.state {
        case .idle, .publishing: return .secondary
        case .synced: return .green
        case .outOfDate: return .red
        }
    }

    private var footer: String {
        if needsAttention {
            return "Spectators will see your previous settings. This retries "
                + "automatically as soon as you are back online."
        }
        return "Spectators receive these settings from the service. Publish Now sends them again."
    }
}
