import SwiftUI
import ForceShared

/// Host wrapper around the shared calculator. Everything the calculator actually does
/// lives in `CalculatorViewRoot`; the host's only job is to decide how "dismiss"
/// behaves — swap the root screen back to settings when the calculator was launched
/// as the app's initial root, fall back to the environment dismiss when it was
/// presented as a full-screen cover.
struct CalculatorView: View {
    /// Called when the top-bar dismiss button is tapped. Set when the calculator is
    /// the window's root and dismissing has to swap the root out instead of popping
    /// a cover; left nil when presented as a full-screen cover, where the environment
    /// `dismiss` handles it.
    var onDismiss: (() -> Void)?

    @EnvironmentObject private var settings: CalculatorSettings
    @Environment(\.dismiss) private var dismiss

    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        debugLog("🧮 CalculatorView: Initializing")
    }

    var body: some View {
        CalculatorViewRoot(
            settings: settings,
            onDismiss: dismissCalculator
        )
    }

    /// Prefers the caller-supplied dismiss when there is one, so the calculator can
    /// tell the root switcher to swap back to settings. Falls back to the environment
    /// dismiss when the view was presented as a full-screen cover and there is no
    /// root to swap. The Perfect Plus lockout is applied by `CalculatorViewRoot`.
    private func dismissCalculator() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}
