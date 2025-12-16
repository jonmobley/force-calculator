import SwiftUI

// MARK: - Button Grid Component

struct CalculatorButtonGrid: View {
    @ObservedObject var settings: CalculatorSettings
    @Binding var showForceNumber: Bool
    @Binding var showModeText: Bool
    let digitAction: (String) -> Void
    let decimalAction: () -> Void
    let backspaceAction: () -> Void
    let clearAction: () -> Void
    let toggleSignAction: () -> Void
    let toggleModeAction: () -> Void
    let operationAction: (CalculatorOperation) -> Void
    let equalsAction: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Row 1: Back, AC, %, ÷
            HStack(spacing: 12) {
                NewIconCalculatorButton(
                    iconName: "icon-back",
                    backgroundColor: Color(hex: "5c5c5f"),
                    pressedBackgroundColor: Color(hex: "8c8c8c"),
                    action: backspaceAction,
                    iconSize: 38
                )
                NewIconCalculatorButton(
                    iconName: "icon-ac",
                    backgroundColor: Color(hex: "5c5c5f"),
                    pressedBackgroundColor: Color(hex: "8c8c8c"),
                    action: clearAction,
                    iconSize: 38
                )
                NewIconCalculatorButton(
                    iconName: "icon-percent",
                    backgroundColor: Color(hex: "5c5c5f"),
                    pressedBackgroundColor: Color(hex: "8c8c8c"),
                    action: { operationAction(.percent) },
                    iconSize: 36
                )
                NewIconCalculatorButton(
                    iconName: "icon-divide",
                    backgroundColor: settings.buttonTheme.color,
                    pressedBackgroundColor: settings.buttonTheme.pressedColorValue,
                    action: { operationAction(.divide) },
                    iconSize: 38
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
                    backgroundColor: settings.buttonTheme.color,
                    pressedBackgroundColor: settings.buttonTheme.pressedColorValue,
                    action: { operationAction(.multiply) },
                    iconSize: 34
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
                    backgroundColor: settings.buttonTheme.color,
                    pressedBackgroundColor: settings.buttonTheme.pressedColorValue,
                    action: { operationAction(.subtract) },
                    iconSize: 34
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
                    backgroundColor: settings.buttonTheme.color,
                    pressedBackgroundColor: settings.buttonTheme.pressedColorValue,
                    action: { operationAction(.add) },
                    iconSize: 34
                )
            }
            
            // Row 5: +/-, 0, ., =
            HStack(spacing: 12) {
                NewIconCalculatorButton(
                    iconName: "icon-plusminus",
                    backgroundColor: Color(hex: "2a2a2c"),
                    pressedBackgroundColor: Color(hex: "727272"),
                    action: toggleModeAction,
                    iconSize: 36
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
                
                EqualsButtonWithPeek(
                    showForceNumber: $showForceNumber,
                    action: equalsAction
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 34) // Safe area bottom padding
    }
}
