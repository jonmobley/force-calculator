import SwiftUI
import Foundation
import ForceShared

struct CalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var display = "0"
    @State private var currentNumber: Double = 0
    @State private var previousNumber: Double = 0
    @State private var operation: CalculatorOperation? = nil
    @State private var userIsTyping = false
    @State private var forceCount = 0
    // Use EnvironmentObject for settings to ensure consistency across app
    @EnvironmentObject var settings: CalculatorSettings
    @State private var lastButtonWasOperation = false
    @State private var lastMinuteChecked: Int? = nil
    @State private var hasUpdatedForMinuteChange = false
    @State private var showForceNumber = false
    @State private var showModeText = false
    @State private var modeHideWorkItem: DispatchWorkItem?

    /// How long the mode badge stays visible after a reveal or a mode change.
    private let modeRevealDuration: TimeInterval = 3
    
    // Plus Perfect state lives on the handler, which orientation changes drive directly.
    @State private var lastOperationWasEquals = false
    @StateObject private var plusPerfectHandler = PlusPerfectHandler()
    
    // For repeat equals functionality
    @State private var lastOperation: CalculatorOperation? = nil
    @State private var lastOperand: Double = 0
    @State private var hasEntryToClear = false
    
    init() {
        debugLog("🧮 CalculatorView: Initializing")
    }
    
    typealias Operation = CalculatorOperation
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HostCalculatorDisplay(
                    display: display,
                    geometry: geometry,
                    themeColor: settings.buttonTheme.color,
                    showForceNumber: showForceNumber,
                    forceNumber: settings.forceNumber,
                    showModeText: showModeText,
                    modeName: settings.magicTrickMode.rawValue,
                    onDismiss: { dismiss() },
                    onToggleMode: toggleMode,
                    onRevealMode: revealMode
                )
                CalculatorButtonGrid(
                    settings: settings,
                    showForceNumber: $showForceNumber,
                    digitAction: digitPressed,
                    decimalAction: decimalPressed,
                    backspaceAction: backspace,
                    clearAction: hasEntryToClear ? clearEntry : clearAll,
                    toggleSignAction: toggleSign,
                    operationAction: { performOperation($0) },
                    equalsAction: equals
                )
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            debugLog("🧮 CalculatorView: onAppear called")
            forceCount = 0
            debugLog("🎭 Plus Perfect: Starting orientation monitoring (enabled: \(settings.plusPerfectEnabled))")
            plusPerfectHandler.startMonitoring {
                calculatePerfectAddend()
            }
            debugLog("✅ CalculatorView: onAppear completed")
        }
        .onDisappear {
            plusPerfectHandler.stopMonitoring()
            modeHideWorkItem?.cancel()
        }
    }
    
    // MARK: - Calculator Logic
    
    private func digitPressed(_ digit: String) {
        CalculatorOperations.digitPressed(
            digit,
            display: &display,
            userIsTyping: &userIsTyping,
            lastOperationWasEquals: &lastOperationWasEquals,
            plusPerfectMode: plusPerfectHandler.mode
        )
        hasEntryToClear = true
    }
    
    private func decimalPressed() {
        CalculatorOperations.decimalPressed(
            display: &display,
            userIsTyping: &userIsTyping,
            lastOperationWasEquals: &lastOperationWasEquals,
            plusPerfectMode: plusPerfectHandler.mode
        )
        hasEntryToClear = true
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
        hasEntryToClear = false
    }
    
    private func clearEntry() {
        CalculatorOperations.clearEntry(
            display: &display,
            userIsTyping: &userIsTyping
        )
        hasEntryToClear = false
    }
    
    private func backspace() {
        CalculatorOperations.backspace(
            display: &display,
            userIsTyping: &userIsTyping,
            plusPerfectMode: plusPerfectHandler.mode
        )
        // Update hasEntryToClear based on whether display is "0"
        hasEntryToClear = (display != "0")
    }
    
    private func toggleSign() {
        CalculatorOperations.toggleSign(
            display: &display,
            plusPerfectMode: plusPerfectHandler.mode
        )
    }
    
    /// Shows the hidden mode badge long enough to read it or tap it.
    private func revealMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showModeText = true
        }
        scheduleModeHide()
        debugLog("👁️ Mode revealed: \(settings.magicTrickMode)")
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

    private func toggleMode() {
        settings.magicTrickMode = settings.magicTrickMode == .forceNumber ? .exactDateTime : .forceNumber
        scheduleModeHide()
        debugLog("🔄 Mode toggled to: \(settings.magicTrickMode)")
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
        // After operation, there's no entry to clear (result is shown)
        hasEntryToClear = false
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
        // After equals, there's no entry to clear (result is shown)
        hasEntryToClear = false
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
