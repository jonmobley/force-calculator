import SwiftUI
import ForceShared

/// Host readout. The layout itself lives in `CalculatorReadout` so the App Clip
/// renders identically; the host simply adds the menu button.
struct HostCalculatorDisplay: View {
    let display: String
    let geometry: GeometryProxy
    let themeColor: Color
    let showForceNumber: Bool
    let showModeText: Bool
    let modeName: String
    let forcedNumber: Int
    let onDismiss: () -> Void
    let onQuickEntry: () -> Void
    let quickEntryStage: QuickForceEntry.Stage
    let onToggleMode: () -> Void
    let onRevealMode: () -> Void

    var body: some View {
        CalculatorReadout(
            display: display,
            geometry: geometry,
            themeColor: themeColor,
            showForceNumber: showForceNumber,
            showModeText: showModeText,
            modeName: modeName,
            forcedNumber: forcedNumber,
            onDismiss: onDismiss,
            onQuickEntry: onQuickEntry,
            quickEntryStage: quickEntryStage,
            onToggleMode: onToggleMode,
            onRevealMode: onRevealMode
        )
    }
}
