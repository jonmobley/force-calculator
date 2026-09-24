import SwiftUI
import ForceShared

/// Host keypad. The keys live in `CalculatorKeypad` so the App Clip shows exactly
/// the same layout and sizes.
struct CalculatorButtonGrid: View {
    @ObservedObject var settings: CalculatorSettings
    @Binding var showForceNumber: Bool
    var selectedOperation: CalculatorOperation? = nil
    let digitAction: (String) -> Void
    let decimalAction: () -> Void
    let backspaceAction: () -> Void
    let clearAction: () -> Void
    let toggleSignAction: () -> Void
    let operationAction: (CalculatorOperation) -> Void
    let equalsAction: () -> Void

    var body: some View {
        CalculatorKeypad(
            settings: settings,
            showForceNumber: $showForceNumber,
            selectedOperation: selectedOperation,
            digitAction: digitAction,
            decimalAction: decimalAction,
            backspaceAction: backspaceAction,
            clearAction: clearAction,
            toggleSignAction: toggleSignAction,
            operationAction: operationAction,
            equalsAction: equalsAction
        )
    }
}
