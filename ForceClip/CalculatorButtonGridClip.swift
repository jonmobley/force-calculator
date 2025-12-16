import SwiftUI

// MARK: - Button Grid Component

struct CalculatorButtonGridClip: View {
    @ObservedObject var settings: CalculatorSettings
    let showBackButton: Bool
    let digitAction: (String) -> Void
    let decimalAction: () -> Void
    let backspaceAction: () -> Void
    let clearAction: () -> Void
    let toggleSignAction: () -> Void
    let operationAction: (CalculatorView.Operation) -> Void
    let equalsAction: () -> Void
    let toggleModeAction: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Row 1: AC/Back, +/-, %, ÷
            HStack(spacing: 12) {
                NewIconCalculatorButton(
                    iconName: showBackButton ? "icon-back" : "icon-ac",
                    backgroundColor: Color(hex: "5c5c5f"),
                    pressedBackgroundColor: Color(hex: "8c8c8c"),
                    action: { showBackButton ? backspaceAction() : clearAction() },
                    iconSize: 32
                )
                NewIconCalculatorButton(
                    iconName: "icon-plusminus",
                    backgroundColor: Color(hex: "5c5c5f"),
                    pressedBackgroundColor: Color(hex: "8c8c8c"),
                    action: toggleSignAction,
                    iconSize: 30
                )
                NewIconCalculatorButton(
                    iconName: "icon-percent",
                    backgroundColor: Color(hex: "5c5c5f"),
                    pressedBackgroundColor: Color(hex: "8c8c8c"),
                    action: { operationAction(.percent) },
                    iconSize: 30
                )
                NewIconCalculatorButton(
                    iconName: "icon-divide",
                    backgroundColor: Color(hex: "ff9f0a"),
                    pressedBackgroundColor: Color(hex: "fcc78d"),
                    action: { operationAction(.divide) },
                    iconSize: 32
                )
            }
            
            // Row 2: 7, 8, 9, ×
            HStack(spacing: 12) {
                NewCalculatorButton(
                    title: "7",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    titleColor: .white,
                    action: { digitAction("7") }
                )
                NewCalculatorButton(
                    title: "8",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    titleColor: .white,
                    action: { digitAction("8") }
                )
                NewCalculatorButton(
                    title: "9",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    titleColor: .white,
                    action: { digitAction("9") }
                )
                NewIconCalculatorButton(
                    iconName: "icon-multiply",
                    backgroundColor: Color(hex: "ff9f0a"),
                    pressedBackgroundColor: Color(hex: "fcc78d"),
                    action: { operationAction(.multiply) },
                    iconSize: 28
                )
            }
            
            // Row 3: 4, 5, 6, -
            HStack(spacing: 12) {
                NewCalculatorButton(
                    title: "4",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    titleColor: .white,
                    action: { digitAction("4") }
                )
                NewCalculatorButton(
                    title: "5",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    titleColor: .white,
                    action: { digitAction("5") }
                )
                NewCalculatorButton(
                    title: "6",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    titleColor: .white,
                    action: { digitAction("6") }
                )
                NewIconCalculatorButton(
                    iconName: "icon-minus",
                    backgroundColor: Color(hex: "ff9f0a"),
                    pressedBackgroundColor: Color(hex: "fcc78d"),
                    action: { operationAction(.subtract) },
                    iconSize: 28
                )
            }
            
            // Row 4: 1, 2, 3, +
            HStack(spacing: 12) {
                NewCalculatorButton(
                    title: "1",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    titleColor: .white,
                    action: { digitAction("1") }
                )
                NewCalculatorButton(
                    title: "2",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    titleColor: .white,
                    action: { digitAction("2") }
                )
                NewCalculatorButton(
                    title: "3",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    titleColor: .white,
                    action: { digitAction("3") }
                )
                NewIconCalculatorButton(
                    iconName: "icon-plus",
                    backgroundColor: Color(hex: "ff9f0a"),
                    pressedBackgroundColor: Color(hex: "fcc78d"),
                    action: { operationAction(.add) },
                    iconSize: 28
                )
            }
            
            // Row 5: Calculator icon, 0, ., =
            HStack(spacing: 12) {
                NewIconCalculatorButton(
                    iconName: "icon-calculator",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    action: toggleModeAction,
                    iconSize: settings.magicTrickMode == .exactDateTime ? 44 : 36
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
                
                NewIconCalculatorButton(
                    iconName: "icon-equal",
                    backgroundColor: Color(hex: "ff9f0a"),
                    pressedBackgroundColor: Color(hex: "fcc78d"),
                    action: equalsAction,
                    iconSize: 28
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 34) // Safe area bottom padding
    }
}
