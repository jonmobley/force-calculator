import SwiftUI
import ForceShared

struct CalculatorView: View {
    @EnvironmentObject var settings: CalculatorSettings

    /// The whole calculator session, held as one value so the shared key handling takes a
    /// single binding.
    @State private var calc = CalculatorState()

    @State private var showForceNumber = false
    @State private var showModeText = false
    @State private var modeHideWorkItem: DispatchWorkItem?

    @StateObject private var plusPerfectHandler = PlusPerfectHandler()
    @StateObject private var quickForce = QuickForceEntry()
    @StateObject private var peek = PeekReporter()

    /// What equals will land on, and after how many presses: the performer's published
    /// settings unless the clock button has been used to override them for this session.
    private var force: ForceValues { quickForce.values(settings: settings) }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                CalculatorReadout(
                    display: calc.display,
                    geometry: geometry,
                    themeColor: settings.buttonTheme.color,
                    showForceNumber: showForceNumber,
                    showModeText: showModeText,
                    modeName: quickForce.modeName(settings: settings),
                    forcedNumber: force.number,
                    onQuickEntry: toggleQuickEntry,
                    quickEntryStage: quickForce.stage,
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
        calc.forceCount = 0
        plusPerfectHandler.startMonitoring { calculatePerfectAddend() }
    }

    private func stopSession() {
        peek.flush(calc.display, enabled: settings.livePeekEnabled, suppressed: peekSuppressed)
        peek.stop()
        plusPerfectHandler.stopMonitoring()
        modeHideWorkItem?.cancel()
        // The override is good for one sitting only, so closing the calculator
        // hands the trick back to the performer's published settings.
        quickForce.reset()
    }

    /// Live peek must report the spectator's number, never the performer's own
    /// setup. The covert clock sequence types the force number straight onto the
    /// display, and an armed Plus Perfect leaves a staged value there, so peek
    /// stays quiet through both.
    private var peekSuppressed: Bool {
        quickForce.isArmed || plusPerfectHandler.mode == .armed
    }

    private func reportPeek() {
        peek.report(calc.display, enabled: settings.livePeekEnabled, suppressed: peekSuppressed)
    }

    /// Shows the hidden mode badge long enough to read.
    private func revealMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showModeText = true
        }
        scheduleModeHide()
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

    /// Starts covert force entry, or abandons a sequence already running. The display is
    /// wiped either way, so the performer types into a clean readout and nothing is left
    /// sitting there if they back out.
    private func toggleQuickEntry() {
        resetEntry()
        quickForce.toggle()
    }

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
        reportPeek()
    }

    private func decimalPressed() {
        CalculatorOperations.decimalPressed(state: &calc, plusPerfectMode: plusPerfectHandler.mode)
        reportPeek()
    }

    private func backspace() {
        CalculatorOperations.backspace(state: &calc, plusPerfectMode: plusPerfectHandler.mode)
        reportPeek()
    }

    /// Clear is the way out of an armed clock, the same way it backs out of Plus Perfect.
    /// An override already committed survives it, so a spectator clearing the display
    /// cannot undo the setup.
    private func clearAll() {
        quickForce.cancel()
        resetEntry()
    }

    private func resetEntry() {
        CalculatorOperations.clearAll(state: &calc, plusPerfectHandler: plusPerfectHandler)
    }

    private func toggleSign() {
        CalculatorOperations.toggleSign(state: &calc, plusPerfectMode: plusPerfectHandler.mode)
        reportPeek()
    }

    /// Changes Force versus Date/Time for this clip session only. The performer's
    /// published settings are untouched.
    private func toggleMode() {
        settings.magicTrickMode = settings.magicTrickMode == .forceNumber ? .exactDateTime : .forceNumber
        scheduleModeHide()
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
    }

    private func equals() {
        // Mid-sequence, equals commits the typed force number instead of calculating.
        if quickForce.consumeEquals(display: calc.display) { return }
        CalculatorOperations.equals(
            state: &calc,
            force: force,
            plusPerfectHandler: plusPerfectHandler
        )
        reportPeek()
    }

    private func calculatePerfectAddend() {
        plusPerfectHandler.calculatePerfectAddend(state: &calc, force: force)
    }
}
