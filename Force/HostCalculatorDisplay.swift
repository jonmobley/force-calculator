import SwiftUI
import ForceShared

/// Host calculator readout and dismiss control.
///
/// The current mode is deliberately hidden so the calculator looks ordinary to a
/// spectator. A long press on the readout reveals it, and while revealed the
/// label can be tapped to switch modes.
struct HostCalculatorDisplay: View {
    let display: String
    let geometry: GeometryProxy
    let themeColor: Color
    let showForceNumber: Bool
    let forceNumber: Int
    let showModeText: Bool
    let modeName: String
    let onDismiss: () -> Void
    let onToggleMode: () -> Void
    let onRevealMode: () -> Void

    var body: some View {
        VStack {
            header
            Spacer()
            readout
        }
        .frame(height: geometry.size.height * 0.35)
    }

    private var header: some View {
        // Top alignment keeps the menu icon still when the mode badge appears.
        HStack(alignment: .top) {
            Button(action: onDismiss) {
                Image("icon-menu")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(themeColor)
            }
            .padding(.leading, 24)
            .padding(.top, 20)
            .accessibilityLabel("Close calculator")
            Spacer()
            trailingStatus
        }
    }

    private var trailingStatus: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if showForceNumber {
                Text("\(forceNumber)")
                    .font(.system(size: 16))
                    .foregroundColor(Color.gray.opacity(0.7))
                    .padding(.trailing, 24)
                    .padding(.top, 20)
            } else if showModeText {
                modeBadge
            }
        }
    }

    private var modeBadge: some View {
        Button(action: onToggleMode) {
            Text(modeName)
                .font(.caption.weight(.semibold))
                .foregroundColor(themeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.trailing, 24)
        .padding(.top, 20)
        .accessibilityLabel("Current mode: \(modeName). Tap to switch.")
    }

    private var readout: some View {
        HStack {
            Spacer()
            Text(display)
                .font(.custom("SF Pro Display", size: min(geometry.size.width * 0.22, 100)))
                .fontWeight(.thin)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .padding(.bottom, 30)
        // Covert reveal. The whole readout row is the target so there is no
        // visible control, and a press here cannot alter the calculation.
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.6, perform: onRevealMode)
    }
}
