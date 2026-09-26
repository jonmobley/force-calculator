import SwiftUI

/// Equals key that peeks the force number on a long press and calculates on a short tap.
///
/// One gesture drives both, rather than a `Button` with a press gesture alongside it. The
/// button fired on every release, so a long press that only meant to glance at the force
/// also pressed equals and moved the activation count on.
public struct EqualsButtonWithPeek: View {
    @EnvironmentObject var settings: CalculatorSettings
    @Binding var showForceNumber: Bool
    let action: () -> Void
    @State private var isPressed = false
    @State private var didPeek = false
    @State private var longPressTimer: Timer?

    public init(
        showForceNumber: Binding<Bool>,
        action: @escaping () -> Void
    ) {
        _showForceNumber = showForceNumber
        self.action = action
    }

    public var body: some View {
        Image("icon-equal", bundle: .main)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 34, height: 34)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .calculatorKeySurface(
                fill: isPressed ? settings.buttonTheme.pressedColorValue : settings.buttonTheme.color
            )
            .contentShape(Rectangle())
            .gesture(pressGesture)
            .onDisappear(perform: cancelTimer)
            .accessibilityElement()
            .accessibilityLabel("Equals")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }

    // MARK: - Press handling

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in beginPress() }
            .onEnded { _ in endPress() }
    }

    private func beginPress() {
        guard !isPressed else { return }
        isPressed = true
        didPeek = false
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            didPeek = true
            withAnimation(.easeInOut(duration: 0.2)) {
                showForceNumber = true
            }
        }
    }

    private func endPress() {
        isPressed = false
        cancelTimer()
        withAnimation(.easeInOut(duration: 0.2)) {
            showForceNumber = false
        }
        if !didPeek {
            action()
        }
        didPeek = false
    }

    private func cancelTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
}
