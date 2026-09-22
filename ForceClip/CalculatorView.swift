import SwiftUI
import ForceShared

struct CalculatorView: View {
    @EnvironmentObject var settings: CalculatorSettings
    @State private var display = "0"
    @State private var currentNumber: Double = 0
    @State private var previousNumber: Double = 0
    @State private var operation: CalculatorOperation?
    @State private var userIsTyping = false
    @State private var forceCount = 0
    @State private var lastButtonWasOperation = false
    @State private var lastMinuteChecked: Int?
    @State private var hasUpdatedForMinuteChange = false
    @State private var showForceNumber = false
    @State private var showModeText = false
    @State private var modeHideWorkItem: DispatchWorkItem?

    /// How long the mode badge stays visible after a reveal or a mode change.
    private let modeRevealDuration: TimeInterval = 3

    @State private var lastOperationWasEquals = false
    @StateObject private var plusPerfectHandler = PlusPerfectHandler()
    @State private var lastOperation: CalculatorOperation?
    @State private var lastOperand: Double = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                CalculatorReadout(
                    display: display,
                    geometry: geometry,
                    themeColor: settings.buttonTheme.color,
                    showForceNumber: showForceNumber,
                    forceNumber: settings.forceNumber,
                    showModeText: showModeText,
                    modeName: settings.magicTrickMode.rawValue,
                    onToggleMode: toggleMode,
                    onRevealMode: revealMode
                )
                CalculatorKeypad(
                    settings: settings,
                    showForceNumber: $showForceNumber,
                    digitAction: digitPressed,
                    decimalAction: decimalPressed,
                    backspaceAction: backspace,
                    clearAction: clearAll,
                    toggleSignAction: toggleSign,
                    operationAction: performOperation,
                    equalsAction: equals
                )
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear(perform: startSession)
        .onDisappear(perform: stopSession)
    }

    private func startSession() {
        forceCount = 0
        plusPerfectHandler.startMonitoring { calculatePerfectAddend() }
    }

    private func stopSession() {
        plusPerfectHandler.stopMonitoring()
        modeHideWorkItem?.cancel()
    }

    /// Shows the hidden mode badge long enough to read it or tap it.
    private func revealMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showModeText = true
        }
        scheduleModeHide()
    }

    /// Restarts the auto-hide countdown so a tap does not cut the reveal short.
    private func scheduleModeHide() {
        modeHideWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showModeText = false
            }
        }
        modeHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + modeRevealDuration, execute: workItem)
    }

    private func digitPressed(_ digit: String) {
        CalculatorOperations.digitPressed(
            digit,
            display: &display,
            userIsTyping: &userIsTyping,
            lastOperationWasEquals: &lastOperationWasEquals,
            plusPerfectMode: plusPerfectHandler.mode
        )
    }

    private func decimalPressed() {
        CalculatorOperations.decimalPressed(
            display: &display,
            userIsTyping: &userIsTyping,
            lastOperationWasEquals: &lastOperationWasEquals,
            plusPerfectMode: plusPerfectHandler.mode
        )
    }

    private func backspace() {
        CalculatorOperations.backspace(
            display: &display,
            userIsTyping: &userIsTyping,
            plusPerfectMode: plusPerfectHandler.mode
        )
    }

    private func clearAll() {
        CalculatorOperations.clearAll(
            display: &display,
            currentNumber: &currentNumber,
            previousNumber: &previousNumber,
            operation: &operation,
            userIsTyping: &userIsTyping,
            forceCount: &forceCount,
            lastMinuteChecked: &lastMinuteChecked,
            hasUpdatedForMinuteChange: &hasUpdatedForMinuteChange,
            plusPerfectHandler: plusPerfectHandler,
            lastOperationWasEquals: &lastOperationWasEquals,
            lastOperation: &lastOperation,
            lastOperand: &lastOperand
        )
    }

    private func toggleSign() {
        CalculatorOperations.toggleSign(display: &display, plusPerfectMode: plusPerfectHandler.mode)
    }

    /// Changes Force versus Date/Time for this clip session only. The performer's
    /// published settings are untouched.
    private func toggleMode() {
        settings.magicTrickMode = settings.magicTrickMode == .forceNumber ? .exactDateTime : .forceNumber
        scheduleModeHide()
    }

    private func performOperation(_ op: CalculatorOperation) {
        CalculatorOperations.performOperation(
            op,
            display: &display,
            previousNumber: &previousNumber,
            operation: &operation,
            userIsTyping: &userIsTyping,
            lastButtonWasOperation: &lastButtonWasOperation,
            lastOperationWasEquals: &lastOperationWasEquals,
            settings: settings,
            plusPerfectHandler: plusPerfectHandler,
            equalsAction: equals
        )
    }

    private func equals() {
        CalculatorOperations.equals(
            display: &display,
            currentNumber: &currentNumber,
            previousNumber: &previousNumber,
            operation: &operation,
            userIsTyping: &userIsTyping,
            lastButtonWasOperation: &lastButtonWasOperation,
            lastOperationWasEquals: &lastOperationWasEquals,
            forceCount: &forceCount,
            lastMinuteChecked: &lastMinuteChecked,
            hasUpdatedForMinuteChange: &hasUpdatedForMinuteChange,
            settings: settings,
            plusPerfectHandler: plusPerfectHandler,
            lastOperation: &lastOperation,
            lastOperand: &lastOperand
        )
    }

    private func calculatePerfectAddend() {
        plusPerfectHandler.calculatePerfectAddend(
            display: &display,
            operation: &operation,
            previousNumber: &previousNumber,
            currentNumber: &currentNumber,
            userIsTyping: &userIsTyping,
            settings: settings
        )
    }
}
