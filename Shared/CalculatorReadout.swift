import SwiftUI

/// The number display and its hidden status area, shared by both targets.
///
/// The current mode is deliberately not shown: a permanent badge would tell a
/// spectator the calculator is rigged. A long press on the readout reveals it, and
/// while revealed the label can be tapped to switch modes.
public struct CalculatorReadout: View {
    /// How long the mode badge stays up after a reveal or a mode change. Long enough to
    /// read two words and no longer: the badge is the one thing on screen that gives the
    /// trick away, and it is read only by the performer. Lives here so the host app and
    /// the App Clip cannot drift apart on it.
    public static let modeRevealDuration: TimeInterval = 1.5

    let display: String
    let geometry: GeometryProxy
    let themeColor: Color
    let showForceNumber: Bool
    let showModeText: Bool
    let modeName: String
    /// What equals will land on in the current mode. Feeds both the equals-key peek and
    /// the mode badge, so the two can never disagree about what is coming.
    let forcedNumber: Int
    /// Omitted by the App Clip, which has no menu to return to.
    let onDismiss: (() -> Void)?
    /// Starts or abandons covert force entry from the clock button.
    let onQuickEntry: (() -> Void)?
    /// Drives the clock's active state, so the performer can see how far the
    /// clock-button sequence has got without anything being spelled out on screen.
    let quickEntryStage: QuickForceEntry.Stage
    let onToggleMode: () -> Void
    let onRevealMode: () -> Void

    public init(
        display: String,
        geometry: GeometryProxy,
        themeColor: Color,
        showForceNumber: Bool,
        showModeText: Bool,
        modeName: String,
        forcedNumber: Int,
        onDismiss: (() -> Void)? = nil,
        onQuickEntry: (() -> Void)? = nil,
        quickEntryStage: QuickForceEntry.Stage = .idle,
        onToggleMode: @escaping () -> Void,
        onRevealMode: @escaping () -> Void
    ) {
        self.display = display
        self.geometry = geometry
        self.themeColor = themeColor
        self.showForceNumber = showForceNumber
        self.showModeText = showModeText
        self.modeName = modeName
        self.forcedNumber = forcedNumber
        self.onDismiss = onDismiss
        self.onQuickEntry = onQuickEntry
        self.quickEntryStage = quickEntryStage
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

        /// Long enough that a tap meant to arm the sequence cannot leave the calculator
        /// by accident, short enough not to feel like a stuck button.
        static let dismissHoldDuration: TimeInterval = 0.45
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

    /// Left control. Stock iOS shows calculation history here; a tap starts covert force
    /// entry, and in the host app a hold is the way back to the menu.
    ///
    /// The tap gets the quick gesture because it is the one performed in company and has
    /// to look like nothing; leaving the calculator is deliberate and can afford a hold.
    private var historyButton: some View {
        circularSurface(fill: quickEntryFill) {
            Image(systemName: "clock")
                .font(.system(size: 19, weight: .regular))
                .foregroundColor(quickEntryGlyph)
        }
        .contentShape(Circle())
        .gesture(historyGesture)
        .allowsHitTesting(onQuickEntry != nil || onDismiss != nil)
        // Named for what a spectator would expect rather than what it does, and the
        // way out is offered as a separate action so it stays reachable under VoiceOver.
        .accessibilityLabel("History")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Close calculator") { onDismiss?() }
    }

    /// A hold has to win outright: were the tap delivered as well, leaving the
    /// calculator would arm the sequence on the way out.
    private var historyGesture: some Gesture {
        ExclusiveGesture(
            LongPressGesture(minimumDuration: Metrics.dismissHoldDuration),
            TapGesture()
        )
        .onEnded { outcome in
            switch outcome {
            case .first:
                // The clip has no menu to return to, so a hold there simply arms.
                (onDismiss ?? onQuickEntry)?()
            case .second:
                onQuickEntry?()
            }
        }
    }

    /// Tinted rather than badged. Stock iOS lights this control while the history panel
    /// is open, so an armed clock reads as a panel the spectator merely cannot see.
    private var quickEntryFill: Color {
        quickEntryStage == .awaitingActivation ? themeColor : Metrics.controlFill
    }

    private var quickEntryGlyph: Color {
        switch quickEntryStage {
        case .idle: return Metrics.glyph
        case .awaitingNumber: return themeColor
        // Inverted, so the one press that still has to land is unmistakable.
        case .awaitingActivation: return Metrics.controlFill
        }
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
            circularSurface(glyph: glyph)
        }
    }

    private func circularSurface<Glyph: View>(
        fill: Color = Metrics.controlFill,
        @ViewBuilder glyph: () -> Glyph
    ) -> some View {
        glyph()
            .frame(width: Metrics.controlDiameter, height: Metrics.controlDiameter)
            .calculatorKeySurface(fill: fill)
    }

    private var trailingStatus: some View {
        VStack(alignment: .trailing, spacing: 6) {
            modeButton
            if showForceNumber {
                Text(forcedNumberText)
                    .font(.system(size: 16))
                    .foregroundColor(Color.gray.opacity(0.7))
                    .monospacedDigit()
            } else if showModeText {
                modeBadge
            }
        }
    }

    /// Shown only after a reveal, so nothing on screen advertises the mode. The mode name
    /// alone does not tell the performer what equals is about to produce, so the number
    /// itself sits underneath it.
    private var modeBadge: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(modeName)
                .font(.caption2.weight(.semibold))
                .foregroundColor(themeColor.opacity(0.75))
            Text(forcedNumberText)
                .font(.callout.weight(.semibold))
                .foregroundColor(themeColor)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Current mode: \(modeName), \(forcedNumberText)")
    }

    /// Grouped the same way as the main display, so it reads like the result the spectator
    /// will see rather than a bare integer.
    private var forcedNumberText: String {
        CalculatorFormatter.formatResult(Double(forcedNumber))
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
                // Expressions like `1,234 + 5,678` need more room than a lone result.
                .minimumScaleFactor(0.28)
                .lineLimit(1)
        }
        .padding(.bottom, 30)
        // Covert reveal. The whole readout row is the target so there is no
        // visible control, and a press here cannot alter the calculation.
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.6, perform: onRevealMode)
    }
}
