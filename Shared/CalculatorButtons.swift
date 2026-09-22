import SwiftUI

/// Round key with a text label.
///
/// Lives here rather than in each target because the host app and the App Clip
/// previously kept their own copies, which silently drifted: clip digits were
/// 32pt against the app's 38pt, so the same calculator looked different depending
/// on how it was launched.
public struct NewCalculatorButton: View {
    let title: String
    let backgroundColor: Color
    let pressedBackgroundColor: Color
    let titleColor: Color
    let action: () -> Void
    @State private var isPressed = false

    public init(
        title: String,
        backgroundColor: Color,
        pressedBackgroundColor: Color,
        titleColor: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.pressedBackgroundColor = pressedBackgroundColor
        self.titleColor = titleColor
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 38, weight: .medium))
                .foregroundColor(titleColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(isPressed ? pressedBackgroundColor : backgroundColor)
                .cornerRadius(1000)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

/// Round key showing one of the calculator glyphs.
public struct NewIconCalculatorButton: View {
    let iconName: String
    let backgroundColor: Color
    let pressedBackgroundColor: Color
    let action: () -> Void
    let iconSize: CGFloat
    @State private var isPressed = false

    public init(
        iconName: String,
        backgroundColor: Color,
        pressedBackgroundColor: Color,
        action: @escaping () -> Void,
        iconSize: CGFloat = 36
    ) {
        self.iconName = iconName
        self.backgroundColor = backgroundColor
        self.pressedBackgroundColor = pressedBackgroundColor
        self.action = action
        self.iconSize = iconSize
    }

    public var body: some View {
        Button(action: action) {
            // `.main` so each target draws from its own asset catalog rather than
            // this framework's bundle.
            Image(iconName, bundle: .main)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(isPressed ? pressedBackgroundColor : backgroundColor)
                .cornerRadius(1000)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
