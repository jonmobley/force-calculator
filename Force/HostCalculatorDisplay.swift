import SwiftUI
import ForceShared

/// Host readout. The layout itself lives in `CalculatorReadout` so the App Clip
/// renders identically; the host simply adds the menu button.
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
        CalculatorReadout(
            display: display,
            geometry: geometry,
            themeColor: themeColor,
            showForceNumber: showForceNumber,
            forceNumber: forceNumber,
            showModeText: showModeText,
            modeName: modeName,
            onDismiss: onDismiss,
            onToggleMode: onToggleMode,
            onRevealMode: onRevealMode
        )
    }
}
