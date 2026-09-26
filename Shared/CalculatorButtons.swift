import SwiftUI

/// The hairline rim the stock iOS keys carry. It reads as a lit edge rather than a
/// drawn outline: brightest along the top where the light falls, almost gone by the
/// lower middle, then lifting slightly at the very bottom the way a glass edge picks
/// up bounce from below.
enum CalculatorKeyRim {
    static let width: CGFloat = 1

    static let gradient = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.30), location: 0),
            .init(color: .white.opacity(0.10), location: 0.45),
            .init(color: .white.opacity(0.04), location: 0.72),
            .init(color: .white.opacity(0.12), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension View {
    /// Fills a round key and edges it with the glass rim, so every key gets the same
    /// treatment from one place.
    func calculatorKeySurface(fill: Color) -> some View {
        background(fill)
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(CalculatorKeyRim.gradient, lineWidth: CalculatorKeyRim.width)
            )
    }
}

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
                // Measured against stock iOS: a 26pt cap height with a 0.09em
                // stem, which is `regular` at 37pt rather than `medium` at 38pt.
                .font(.system(size: 37, weight: .regular))
                .foregroundColor(titleColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .calculatorKeySurface(fill: isPressed ? pressedBackgroundColor : backgroundColor)
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
                .calculatorKeySurface(
                    fill: isPressed ? pressedBackgroundColor : backgroundColor
                )
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
