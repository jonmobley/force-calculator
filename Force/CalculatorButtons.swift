import SwiftUI

struct NewCalculatorButton: View {
    let title: String
    let backgroundColor: Color
    let pressedBackgroundColor: Color
    let titleColor: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("SF Pro Display", size: 38))
                .fontWeight(.medium)
                .foregroundColor(titleColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(isPressed ? pressedBackgroundColor : backgroundColor)
                .cornerRadius(1000) // Large radius for perfect circle
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct NewIconCalculatorButton: View {
    let iconName: String
    let backgroundColor: Color
    let pressedBackgroundColor: Color
    let action: () -> Void
    let iconSize: CGFloat
    @State private var isPressed = false
    
    init(iconName: String, backgroundColor: Color, pressedBackgroundColor: Color, action: @escaping () -> Void, iconSize: CGFloat = 36) {
        self.iconName = iconName
        self.backgroundColor = backgroundColor
        self.pressedBackgroundColor = pressedBackgroundColor
        self.action = action
        self.iconSize = iconSize
    }
    
    var body: some View {
        Button(action: action) {
            Image(iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(isPressed ? pressedBackgroundColor : backgroundColor)
                .cornerRadius(1000) // Large radius for perfect circle
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// Special equals button with long-press peek functionality
struct EqualsButtonWithPeek: View {
    @EnvironmentObject var settings: CalculatorSettings
    @Binding var showForceNumber: Bool
    let action: () -> Void
    @State private var isPressed = false
    @State private var longPressTimer: Timer?
    
    var body: some View {
        Button(action: action) {
            Image("icon-equal")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(isPressed ? settings.buttonTheme.pressedColorValue : settings.buttonTheme.color)
                .cornerRadius(1000)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        debugLog("👆 Equals button pressed - starting peek timer")
                        // Start timer to show force number after 0.3 seconds
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                            debugLog("👁️ Showing force number")
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showForceNumber = true
                            }
                        }
                    }
                }
                .onEnded { _ in
                    debugLog("👆 Equals button released - hiding force number")
                    isPressed = false
                    // Cancel timer if user lifts before 0.3s
                    longPressTimer?.invalidate()
                    longPressTimer = nil
                    // Hide force number
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showForceNumber = false
                    }
                }
        )
    }
}
