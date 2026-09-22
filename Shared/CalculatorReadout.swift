import SwiftUI

/// The number display and its hidden status area, shared by both targets.
///
/// The current mode is deliberately not shown: a permanent badge would tell a
/// spectator the calculator is rigged. A long press on the readout reveals it, and
/// while revealed the label can be tapped to switch modes.
public struct CalculatorReadout: View {
    let display: String
    let geometry: GeometryProxy
    let themeColor: Color
    let showForceNumber: Bool
    let forceNumber: Int
    let showModeText: Bool
    let modeName: String
    /// Omitted by the App Clip, which has no menu to return to.
    let onDismiss: (() -> Void)?
    let onToggleMode: () -> Void
    let onRevealMode: () -> Void

    public init(
        display: String,
        geometry: GeometryProxy,
        themeColor: Color,
        showForceNumber: Bool,
        forceNumber: Int,
        showModeText: Bool,
        modeName: String,
        onDismiss: (() -> Void)? = nil,
        onToggleMode: @escaping () -> Void,
        onRevealMode: @escaping () -> Void
    ) {
        self.display = display
        self.geometry = geometry
        self.themeColor = themeColor
        self.showForceNumber = showForceNumber
        self.forceNumber = forceNumber
        self.showModeText = showModeText
        self.modeName = modeName
        self.onDismiss = onDismiss
        self.onToggleMode = onToggleMode
        self.onRevealMode = onRevealMode
    }

    public var body: some View {
        VStack {
            header
            Spacer()
            readout
        }
        .frame(height: geometry.size.height * 0.35)
    }

    /// Geometry measured from the stock iOS calculator.
    private enum Metrics {
        static let controlDiameter: CGFloat = 43
        static let controlInset: CGFloat = 16
        static let controlTop: CGFloat = 2
        static let controlFill = Color(hex: "121212")
        static let glyph = Color(white: 0.95)
        static let readoutInset: CGFloat = 16
    }

    private var header: some View {
        // Top alignment keeps the controls still when the mode badge appears.
        HStack(alignment: .top) {
            historyButton
            Spacer()
            trailingStatus
        }
        .padding(.horizontal, Metrics.controlInset)
        .padding(.top, Metrics.controlTop)
    }

    /// Left control. Stock iOS shows calculation history here; the host app uses
    /// the same shape to leave the calculator, and the clip has nowhere to go so
    /// it renders the control without an action.
    private var historyButton: some View {
        circularControl {
            Image(systemName: "clock")
                .font(.system(size: 19, weight: .regular))
                .foregroundColor(Metrics.glyph)
        } action: {
            onDismiss?()
        }
        .accessibilityLabel(onDismiss == nil ? "History" : "Close calculator")
        .allowsHitTesting(onDismiss != nil)
    }

    /// Right control. Reads as the stock mode switcher, and is the covert way to
    /// change Force versus Date/Time.
    private var modeButton: some View {
        circularControl {
            Image("icon-calculator", bundle: .main)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(Metrics.glyph)
        } action: {
            onToggleMode()
            onRevealMode()
        }
        .accessibilityLabel("Switch mode")
    }

    private func circularControl<Glyph: View>(
        @ViewBuilder glyph: () -> Glyph,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            glyph()
                .frame(width: Metrics.controlDiameter, height: Metrics.controlDiameter)
                .background(Metrics.controlFill)
                .clipShape(Circle())
        }
    }

    private var trailingStatus: some View {
        VStack(alignment: .trailing, spacing: 6) {
            modeButton
            if showForceNumber {
                Text("\(forceNumber)")
                    .font(.system(size: 16))
                    .foregroundColor(Color.gray.opacity(0.7))
            } else if showModeText {
                modeBadge
            }
        }
    }

    /// Shown only after a reveal, so nothing on screen advertises the mode.
    private var modeBadge: some View {
        Text(modeName)
            .font(.caption.weight(.semibold))
            .foregroundColor(themeColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel("Current mode: \(modeName)")
    }

    private var readout: some View {
        HStack {
            Spacer()
            Text(display)
                // Measured against stock: 0.165 of the width gives a lone zero a
                // 48pt cap height on a 393pt screen, and stock's stem is about
                // 0.087em, which is `regular` rather than the `thin` used before.
                .font(.system(size: min(geometry.size.width * 0.165, 74), weight: .regular))
                .foregroundColor(.white)
                .padding(.horizontal, Metrics.readoutInset)
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
