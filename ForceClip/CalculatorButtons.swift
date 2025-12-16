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
                .font(.custom("SF Pro Display", size: 32))
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
