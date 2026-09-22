import SwiftUI
import Combine
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
    @State private var plusPerfectMode: PlusPerfectState = .inactive
    @State private var savedNumberForPlusPerfect: Double = 0
    @State private var lastOperationWasEquals = false
    @StateObject private var plusPerfectHandler = PlusPerfectHandler()
    @State private var modeSync: AnyCancellable?
    @State private var lastOperation: CalculatorOperation?
    @State private var lastOperand: Double = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                CalculatorDisplayArea(
                    display: display,
                    geometry: geometry,
                    showForceNumber: showForceNumber,
                    forceNumber: settings.forceNumber
                )
                CalculatorButtonGridClip(
                    settings: settings,
                    showBackButton: display != "0",
                    digitAction: digitPressed,
                    decimalAction: decimalPressed,
                    backspaceAction: backspace,
                    clearAction: clearAll,
                    toggleSignAction: toggleSign,
                    operationAction: performOperation,
                    equalsAction: equals,
                    toggleModeAction: toggleMode,
                    showForceNumber: $showForceNumber
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
        modeSync = plusPerfectHandler.$mode
            .receive(on: DispatchQueue.main)
            .sink { plusPerfectMode = $0 }
    }

    private func stopSession() {
        plusPerfectHandler.stopMonitoring()
        modeSync?.cancel()
    }

    private func digitPressed(_ digit: String) {
        CalculatorOperations.digitPressed(
            digit,
            display: &display,
            userIsTyping: &userIsTyping,
            lastOperationWasEquals: &lastOperationWasEquals,
            plusPerfectMode: plusPerfectMode
        )
    }

    private func decimalPressed() {
        CalculatorOperations.decimalPressed(
            display: &display,
            userIsTyping: &userIsTyping,
            lastOperationWasEquals: &lastOperationWasEquals,
            plusPerfectMode: plusPerfectMode
        )
    }

    private func backspace() {
        CalculatorOperations.backspace(
            display: &display,
            userIsTyping: &userIsTyping,
            plusPerfectMode: plusPerfectMode
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
            plusPerfectMode: &plusPerfectMode,
            savedNumberForPlusPerfect: &savedNumberForPlusPerfect,
            lastOperationWasEquals: &lastOperationWasEquals,
            lastOperation: &lastOperation,
            lastOperand: &lastOperand
        )
        plusPerfectHandler.mode = .inactive
    }

    private func toggleSign() {
        CalculatorOperations.toggleSign(display: &display, plusPerfectMode: plusPerfectMode)
    }

    /// Changes Force versus Date/Time for this clip session only.
    private func toggleMode() {
        settings.magicTrickMode = settings.magicTrickMode == .forceNumber ? .exactDateTime : .forceNumber
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
            plusPerfectMode: &plusPerfectMode,
            savedNumberForPlusPerfect: &savedNumberForPlusPerfect,
            plusPerfectHandler: plusPerfectHandler,
            equalsAction: equals
        )
        plusPerfectMode = plusPerfectHandler.mode
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
            plusPerfectMode: &plusPerfectMode,
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
        plusPerfectMode = plusPerfectHandler.mode
    }
}
