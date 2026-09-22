import SwiftUI
import ForceShared

/// Host calculator readout, dismiss control, and Force versus Date/Time switch.
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

    private var modeLabel: String {
        modeName == MagicTrickMode.forceNumber.rawValue ? "Force" : "Time"
    }

    var body: some View {
        VStack {
            header
            Spacer()
            readout
        }
        .frame(height: geometry.size.height * 0.35)
    }

    private var header: some View {
        HStack {
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
            Button(action: onToggleMode) {
                Text(modeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(themeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.trailing, 24)
            .padding(.top, 20)
            .accessibilityLabel("Force Number or Date and Time")
            if showForceNumber {
                Text("\(forceNumber)")
                    .font(.system(size: 16))
                    .foregroundColor(Color.gray.opacity(0.7))
                    .padding(.trailing, 24)
            } else if showModeText {
                Text(modeName)
                    .font(.system(size: 16))
                    .foregroundColor(Color.gray.opacity(0.7))
                    .padding(.trailing, 24)
            }
        }
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
    }
}
