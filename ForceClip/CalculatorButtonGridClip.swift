import SwiftUI
import ForceShared

struct CalculatorButtonGridClip: View {
    @ObservedObject var settings: CalculatorSettings
    let showBackButton: Bool
    let digitAction: (String) -> Void
    let decimalAction: () -> Void
    let backspaceAction: () -> Void
    let clearAction: () -> Void
    let toggleSignAction: () -> Void
    let operationAction: (CalculatorOperation) -> Void
    let equalsAction: () -> Void
    let toggleModeAction: () -> Void
    @Binding var showForceNumber: Bool

    private var operatorColor: Color { settings.buttonTheme.color }
    private var operatorPressed: Color { settings.buttonTheme.pressedColorValue }

    var body: some View {
        VStack(spacing: 12) {
            topRow
            digitRow(["7", "8", "9"], operation: .multiply, icon: "icon-multiply")
            digitRow(["4", "5", "6"], operation: .subtract, icon: "icon-minus")
            digitRow(["1", "2", "3"], operation: .add, icon: "icon-plus")
            bottomRow
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 34)
    }

    private var topRow: some View {
        HStack(spacing: 12) {
            icon(
                showBackButton ? "icon-back" : "icon-ac",
                color: Color(hex: "5c5c5f"),
                pressed: Color(hex: "8c8c8c"),
                size: 32,
                action: showBackButton ? backspaceAction : clearAction
            )
            icon("icon-plusminus", color: Color(hex: "5c5c5f"), pressed: Color(hex: "8c8c8c"), size: 30, action: toggleSignAction)
            icon("icon-percent", color: Color(hex: "5c5c5f"), pressed: Color(hex: "8c8c8c"), size: 30) {
                operationAction(.percent)
            }
            icon("icon-divide", color: operatorColor, pressed: operatorPressed, size: 32) {
                operationAction(.divide)
            }
        }
    }

    private func digitRow(_ titles: [String], operation: CalculatorOperation, icon iconName: String) -> some View {
        HStack(spacing: 12) {
            ForEach(titles, id: \.self) { title in
                NewCalculatorButton(
                    title: title,
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    titleColor: .white,
                    action: { digitAction(title) }
                )
            }
            icon(iconName, color: operatorColor, pressed: operatorPressed, size: 28) {
                operationAction(operation)
            }
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 12) {
            icon(
                "icon-calculator",
                color: Color(hex: "2a2a2c"),
                pressed: Color(hex: "727272"),
                size: settings.magicTrickMode == .exactDateTime ? 44 : 36,
                action: toggleModeAction
            )
            NewCalculatorButton(
                title: "0",
                backgroundColor: Color(hex: "2a2a2c"),
                pressedBackgroundColor: Color(hex: "727272"),
                titleColor: .white,
                action: { digitAction("0") }
            )
            NewCalculatorButton(
                title: ".",
                backgroundColor: Color(hex: "2a2a2c"),
                pressedBackgroundColor: Color(hex: "727272"),
                titleColor: .white,
                action: decimalAction
            )
            EqualsButtonWithPeek(showForceNumber: $showForceNumber, action: equalsAction)
        }
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
