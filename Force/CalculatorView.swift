import SwiftUI
import Foundation
import ForceShared

struct CalculatorView: View {
    /// Called when the top-bar dismiss button is tapped. Set when the calculator
    /// is the window's root and dismissing has to swap the root out instead of
    /// popping a cover; left nil when presented as a full-screen cover, where the
    /// environment `dismiss` handles it.
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// The whole calculator session, held as one value so the shared key handling takes a
    /// single binding.
    @State private var calc = CalculatorState()

    // Use EnvironmentObject for settings to ensure consistency across app
    @EnvironmentObject var settings: CalculatorSettings
    @State private var showForceNumber = false
    @State private var showModeText = false
    @State private var modeHideWorkItem: DispatchWorkItem?

    
    // Perfect Plus state lives on the handler, which orientation changes drive directly.
    @StateObject private var perfectPlusHandler = PerfectPlusHandler()

    // Covert force entry from the clock button, held here so it lasts a session and no longer.
    @StateObject private var quickForce = QuickForceEntry()

    @State private var hasEntryToClear = false

    /// What equals will land on, and after how many presses: the saved settings unless the
    /// clock button has been used to override them for this session.
    private var force: ForceValues { quickForce.values(settings: settings) }
    
    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
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
                    onDismiss: dismissCalculator,
                    onQuickEntry: toggleQuickEntry,
                    quickEntryStage: quickForce.stage,
                    onToggleMode: toggleMode,
                    onRevealMode: revealMode
                )
                CalculatorButtonGrid(
                    settings: settings,
                    showForceNumber: $showForceNumber,
                    selectedOperation: calc.userIsTyping ? nil : calc.operation,
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
        .simultaneousGesture(screenTouch)
        .onAppear {
            debugLog("🧮 CalculatorView: onAppear called")
            calc.forceCount = 0
            startPerfectPlus()
            debugLog("✅ CalculatorView: onAppear completed")
        }
        // Gravity is sampled ten times a second, which is worth nothing once the calculator
        // is off screen and costs battery in a pocket. Only the sampling stops; a pending or
        // armed trick keeps its state and picks up again on the way back.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                startPerfectPlus()
            } else {
                perfectPlusHandler.stopMonitoring()
            }
        }
        .onDisappear {
            perfectPlusHandler.stopMonitoring()
            modeHideWorkItem?.cancel()
            // The override is good for one sitting only, so closing the calculator hands
            // the trick back to the saved settings.
            quickForce.reset()
        }
    }

    /// Prefers the caller-supplied dismiss when there is one, so the calculator can
    /// tell the root switcher to swap back to settings. Falls back to the
    /// environment dismiss when the view was presented as a full-screen cover and
    /// there is no root to swap.
    private func dismissCalculator() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    private func startPerfectPlus() {
        debugLog("🎭 Perfect Plus: monitoring (enabled: \(settings.perfectPlusEnabled))")
        perfectPlusHandler.startMonitoring(
            hapticsEnabled: settings.perfectPlusHapticsEnabled
        ) {
            calculatePerfectAddend()
        }
    }

    /// Every touch on the calculator, keys included, reported so an armed Perfect Plus can
    /// hold the number back until the phone has been left alone. Recognised alongside the
    /// keys rather than instead of them, so the keypad still works normally.
    private var screenTouch: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in perfectPlusHandler.noteScreenTouch() }
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
            perfectPlusMode: perfectPlusHandler.mode
        )
        if !perfectPlusHoldsTheKeys { hasEntryToClear = true }
    }
    
    private func decimalPressed() {
        CalculatorOperations.decimalPressed(
            state: &calc,
            perfectPlusMode: perfectPlusHandler.mode
        )
        if !perfectPlusHoldsTheKeys { hasEntryToClear = true }
    }
    
    /// Clear is the way out of an armed clock, the same way it backs out of Perfect Plus.
    /// An override already committed survives it, so clearing the display cannot undo the
    /// setup the performer just made.
    private func clearAll() {
        quickForce.cancel()
        resetEntry()
    }

    private func resetEntry() {
        CalculatorOperations.clearAll(state: &calc, perfectPlusHandler: perfectPlusHandler)
        hasEntryToClear = false
    }
    
    private func clearEntry() {
        CalculatorOperations.clearEntry(state: &calc, perfectPlusMode: perfectPlusHandler.mode)
        hasEntryToClear = false
    }
    
    private func backspace() {
        CalculatorOperations.backspace(state: &calc, perfectPlusMode: perfectPlusHandler.mode)
        if !perfectPlusHoldsTheKeys { hasEntryToClear = calc.display != "0" }
    }

    /// While the phone is turned away the keypad is inert, so a tap entered nothing and the
    /// clear key has to stay a full reset. Treating it as an entry would leave clear wiping
    /// an entry that was never made.
    private var perfectPlusHoldsTheKeys: Bool { perfectPlusHandler.mode.keysAreInert }
    
    private func toggleSign() {
        CalculatorOperations.toggleSign(state: &calc, perfectPlusMode: perfectPlusHandler.mode)
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
        if op != .percent,
           CalculatorOperations.shouldFinishPendingSum(calc, perfectPlusMode: perfectPlusHandler.mode) {
            equals()
        }
        CalculatorOperations.performOperation(
            op,
            state: &calc,
            settings: settings,
            perfectPlusHandler: perfectPlusHandler
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
            countActivation: quickForce.countsActivation(settings: settings),
            perfectPlusHandler: perfectPlusHandler
        )
        // After equals, there's no entry to clear (result is shown)
        hasEntryToClear = false
    }
    
    private func calculatePerfectAddend() {
        perfectPlusHandler.calculatePerfectAddend(state: &calc, force: force)
    }
}
