import SwiftUI

/// Equals key that peeks the force number on a long press and calculates on a short tap.
public struct EqualsButtonWithPeek: View {
    @EnvironmentObject var settings: CalculatorSettings
    @Binding var showForceNumber: Bool
    let action: () -> Void
    @State private var isPressed = false
    @State private var longPressTimer: Timer?

    public init(
        showForceNumber: Binding<Bool>,
        action: @escaping () -> Void
    ) {
        _showForceNumber = showForceNumber
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image("icon-equal", bundle: .main)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(isPressed ? settings.buttonTheme.pressedColorValue : settings.buttonTheme.color)
                .cornerRadius(1000)
        }
        .simultaneousGesture(pressGesture)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in beginPress() }
            .onEnded { _ in endPress() }
    }

    private func beginPress() {
        guard !isPressed else { return }
        isPressed = true
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                showForceNumber = true
            }
        }
    }

    private func endPress() {
        isPressed = false
        longPressTimer?.invalidate()
        longPressTimer = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            showForceNumber = false
        }
    }
}
