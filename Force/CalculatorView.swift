import SwiftUI
import Foundation
import ForceShared

struct CalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    /// The whole calculator session, held as one value so the shared key handling takes a
    /// single binding.
    @State private var calc = CalculatorState()

    // Use EnvironmentObject for settings to ensure consistency across app
    @EnvironmentObject var settings: CalculatorSettings
    @State private var showForceNumber = false
    @State private var showModeText = false
    @State private var modeHideWorkItem: DispatchWorkItem?

    
    // Plus Perfect state lives on the handler, which orientation changes drive directly.
    @StateObject private var plusPerfectHandler = PlusPerfectHandler()

    // Covert force entry from the clock button, held here so it lasts a session and no longer.
    @StateObject private var quickForce = QuickForceEntry()

    @State private var hasEntryToClear = false

    /// What equals will land on, and after how many presses: the saved settings unless the
    /// clock button has been used to override them for this session.
    private var force: ForceValues { quickForce.values(settings: settings) }
    
    init() {
        debugLog("🧮 CalculatorView: Initializing")
    }
    
    typealias Operation = CalculatorOperation
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HostCalculatorDisplay(
                    display: calc.display,
                    geometry: geometry,
                    themeColor: settings.buttonTheme.color,
                    showForceNumber: showForceNumber,
                    showModeText: showModeText,
                    modeName: quickForce.modeName(settings: settings),
                    forcedNumber: force.number,
                    onDismiss: { dismiss() },
                    onQuickEntry: toggleQuickEntry,
                    quickEntryStage: quickForce.stage,
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
            calc.forceCount = 0
            debugLog("🎭 Plus Perfect: Starting orientation monitoring (enabled: \(settings.plusPerfectEnabled))")
            plusPerfectHandler.startMonitoring {
                calculatePerfectAddend()
            }
            debugLog("✅ CalculatorView: onAppear completed")
        }
        .onDisappear {
            plusPerfectHandler.stopMonitoring()
            modeHideWorkItem?.cancel()
            // The override is good for one sitting only, so closing the calculator hands
            // the trick back to the saved settings.
            quickForce.reset()
        }
    }

    // MARK: - Covert force entry

    /// Starts covert force entry, or abandons a sequence already running. The display is
    /// wiped either way, so the performer types into a clean readout and nothing is left
    /// sitting there if they back out.
    private func toggleQuickEntry() {
        resetEntry()
        quickForce.toggle()
    }
    
    // MARK: - Calculator Logic
    
    private func digitPressed(_ digit: String) {
        // The clock sequence claims the digit that sets the activation count, which must
        // not also land on the display. Finishing the sequence clears the number the
        // performer typed, leaving the calculator looking untouched.
        if quickForce.consumeDigit(digit) {
            if !quickForce.isArmed { resetEntry() }
            return
        }
        CalculatorOperations.digitPressed(
            digit,
            state: &calc,
            plusPerfectMode: plusPerfectHandler.mode
        )
        if !isPlusPerfectArmed { hasEntryToClear = true }
    }
    
    private func decimalPressed() {
        CalculatorOperations.decimalPressed(
            state: &calc,
            plusPerfectMode: plusPerfectHandler.mode
        )
        if !isPlusPerfectArmed { hasEntryToClear = true }
    }
    
    /// Clear is the way out of an armed clock, the same way it backs out of Plus Perfect.
    /// An override already committed survives it, so clearing the display cannot undo the
    /// setup the performer just made.
    private func clearAll() {
        quickForce.cancel()
        resetEntry()
    }

    private func resetEntry() {
        CalculatorOperations.clearAll(state: &calc, plusPerfectHandler: plusPerfectHandler)
        hasEntryToClear = false
    }
    
    private func clearEntry() {
        CalculatorOperations.clearEntry(state: &calc)
        hasEntryToClear = false
    }
    
    private func backspace() {
        CalculatorOperations.backspace(state: &calc, plusPerfectMode: plusPerfectHandler.mode)
        if !isPlusPerfectArmed { hasEntryToClear = calc.display != "0" }
    }

    /// While Plus Perfect is armed the keypad is inert, so a tap entered nothing and the
    /// clear key has to stay a full reset. Treating it as an entry would spend the
    /// performer's one way out of the armed state on a press that cleared nothing.
    private var isPlusPerfectArmed: Bool { plusPerfectHandler.mode == .armed }
    
    private func toggleSign() {
        CalculatorOperations.toggleSign(state: &calc, plusPerfectMode: plusPerfectHandler.mode)
    }
    
    /// Shows the hidden mode badge long enough to read.
    private func revealMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showModeText = true
        }
        scheduleModeHide()
        debugLog("👁️ Mode revealed: \(settings.magicTrickMode)")
    }

    /// Restarts the auto-hide countdown so a mode change does not cut the reveal short.
    private func scheduleModeHide() {
        modeHideWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showModeText = false
            }
        }
        modeHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + CalculatorReadout.modeRevealDuration,
            execute: workItem
        )
    }

    private func toggleMode() {
        settings.magicTrickMode = settings.magicTrickMode == .forceNumber ? .exactDateTime : .forceNumber
        scheduleModeHide()
        debugLog("🔄 Mode toggled to: \(settings.magicTrickMode)")
    }
    
    private func performOperation(_ op: CalculatorOperation) {
        // An operator pressed part-way through an entry finishes the sum on the go first,
        // so the display carries the running total into the next operation.
        if CalculatorOperations.shouldFinishPendingSum(calc, plusPerfectMode: plusPerfectHandler.mode) {
            equals()
        }
        CalculatorOperations.performOperation(
            op,
            state: &calc,
            settings: settings,
            plusPerfectHandler: plusPerfectHandler
        )
        // After operation, there's no entry to clear (result is shown)
        hasEntryToClear = false
    }
    
    private func equals() {
        // Mid-sequence, equals commits the typed force number instead of calculating.
        if quickForce.consumeEquals(display: calc.display) { return }
        CalculatorOperations.equals(
            state: &calc,
            force: force,
            plusPerfectHandler: plusPerfectHandler
        )
        // After equals, there's no entry to clear (result is shown)
        hasEntryToClear = false
    }
    
    private func calculatePerfectAddend() {
        plusPerfectHandler.calculatePerfectAddend(state: &calc, force: force)
    }
}
