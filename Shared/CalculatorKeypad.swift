import SwiftUI

/// The five-row keypad, shared by the host app and the App Clip.
///
/// Both targets show the same keys in the same positions and at the same sizes so
/// the calculator is indistinguishable whichever way it was launched.
public struct CalculatorKeypad: View {
    @ObservedObject var settings: CalculatorSettings
    @Binding var showForceNumber: Bool
    let digitAction: (String) -> Void
    let decimalAction: () -> Void
    let backspaceAction: () -> Void
    let clearAction: () -> Void
    let toggleSignAction: () -> Void
    let operationAction: (CalculatorOperation) -> Void
    let equalsAction: () -> Void

    /// Geometry measured from the stock iOS calculator: keys sit close together
    /// with wider margins at the screen edges, which yields 85.5pt keys on a
    /// 393pt-wide screen against the stock 85.3pt.
    private static let keyGap: CGFloat = 7
    private static let sideMargin: CGFloat = 15
    private static let bottomMargin: CGFloat = 34

    private static let neutral = Color(hex: "5e5e5e")
    private static let neutralPressed = Color(hex: "8c8c8c")
    private static let digit = Color(hex: "343434")
    private static let digitPressed = Color(hex: "727272")

    private var operatorColor: Color { settings.buttonTheme.color }
    private var operatorPressed: Color { settings.buttonTheme.pressedColorValue }

    public init(
        settings: CalculatorSettings,
        showForceNumber: Binding<Bool>,
        digitAction: @escaping (String) -> Void,
        decimalAction: @escaping () -> Void,
        backspaceAction: @escaping () -> Void,
        clearAction: @escaping () -> Void,
        toggleSignAction: @escaping () -> Void,
        operationAction: @escaping (CalculatorOperation) -> Void,
        equalsAction: @escaping () -> Void
    ) {
        self.settings = settings
        _showForceNumber = showForceNumber
        self.digitAction = digitAction
        self.decimalAction = decimalAction
        self.backspaceAction = backspaceAction
        self.clearAction = clearAction
        self.toggleSignAction = toggleSignAction
        self.operationAction = operationAction
        self.equalsAction = equalsAction
    }

    public var body: some View {
        VStack(spacing: Self.keyGap) {
            topRow
            digitRow(["7", "8", "9"], operation: .multiply, icon: "icon-multiply")
            digitRow(["4", "5", "6"], operation: .subtract, icon: "icon-minus")
            digitRow(["1", "2", "3"], operation: .add, icon: "icon-plus")
            bottomRow
        }
        .padding(.horizontal, Self.sideMargin)
        .padding(.bottom, Self.bottomMargin)
    }

    private var topRow: some View {
        HStack(spacing: Self.keyGap) {
            icon("icon-back", color: Self.neutral, pressed: Self.neutralPressed, size: 38, action: backspaceAction)
            icon("icon-ac", color: Self.neutral, pressed: Self.neutralPressed, size: 38, action: clearAction)
            icon("icon-percent", color: Self.neutral, pressed: Self.neutralPressed, size: 36) {
                operationAction(.percent)
            }
            icon("icon-divide", color: operatorColor, pressed: operatorPressed, size: 38) {
                operationAction(.divide)
            }
        }
    }

    private func digitRow(
        _ titles: [String],
        operation: CalculatorOperation,
        icon iconName: String
    ) -> some View {
        HStack(spacing: Self.keyGap) {
            ForEach(titles, id: \.self) { title in
                digitKey(title)
            }
            icon(iconName, color: operatorColor, pressed: operatorPressed, size: 34) {
                operationAction(operation)
            }
        }
    }

    private var bottomRow: some View {
        HStack(spacing: Self.keyGap) {
            icon("icon-plusminus", color: Self.digit, pressed: Self.digitPressed, size: 36, action: toggleSignAction)
            digitKey("0")
            NewCalculatorButton(
                title: ".",
                backgroundColor: Self.digit,
                pressedBackgroundColor: Self.digitPressed,
                titleColor: .white,
                action: decimalAction
            )
            EqualsButtonWithPeek(showForceNumber: $showForceNumber, action: equalsAction)
        }
    }

    private func digitKey(_ title: String) -> some View {
        NewCalculatorButton(
            title: title,
            backgroundColor: Self.digit,
            pressedBackgroundColor: Self.digitPressed,
            titleColor: .white,
            action: { digitAction(title) }
        )
    }

    private func icon(
        _ name: String,
        color: Color,
        pressed: Color,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        NewIconCalculatorButton(
            iconName: name,
            backgroundColor: color,
            pressedBackgroundColor: pressed,
            action: action,
            iconSize: size
        )
    }
}
