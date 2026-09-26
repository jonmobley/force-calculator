import SwiftUI
import ForceShared

struct CalculatorView: View {
    @EnvironmentObject var settings: CalculatorSettings
    @EnvironmentObject var session: ClipSession
    @Environment(\.scenePhase) private var scenePhase

    /// The whole calculator session, held as one value so the shared key handling takes a
    /// single binding.
    @State private var calc = CalculatorState()

    @State private var showForceNumber = false
    @State private var showModeText = false
    @State private var modeHideWorkItem: DispatchWorkItem?

    @StateObject private var perfectPlusHandler = PerfectPlusHandler()
    @StateObject private var quickForce = QuickForceEntry()
    @StateObject private var peek = PeekReporter()

    /// What equals will land on, and after how many presses: the performer's published
    /// settings unless the clock button has been used to override them for this session.
    private var force: ForceValues { quickForce.values(settings: settings) }

    var body: some View {
        attachSession(to: calculator)
    }

    private var calculator: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                CalculatorReadout(
                    display: calc.expressionDisplay,
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
    }

    /// Launch, peek, and the turn sensor. Kept off the keypad so each stays readable.
    private func attachSession(to view: some View) -> some View {
        view
            .background(Color.black.ignoresSafeArea())
            .simultaneousGesture(screenTouch)
            .onAppear(perform: startSession)
            // The performer's live settings land after the calculator is already up, so the
            // vibration has to be able to change its mind once they arrive.
            .onChange(of: settings.perfectPlusHapticsEnabled) { _, enabled in
                perfectPlusHandler.hapticsEnabled = enabled
            }
            // The invocation URL can arrive after the calculator is already up, so the
            // reporter has to learn whose record to write to once it does.
            .onChange(of: session.performerID) { _, id in
                peek.performerID = id
            }
            // Peek may be switched on after the spectator is already calculating. Send
            // whatever is on screen now, rather than waiting for the next key.
            .onChange(of: settings.livePeekEnabled) { _, enabled in
                guard enabled else { return }
                peek.flush(calc.display, enabled: true, suppressed: peekSuppressed)
            }
            // Gravity is sampled ten times a second, which is worth nothing once the
            // calculator is off screen and costs the spectator battery. Only the sampling
            // stops; a pending or armed trick keeps its state and picks up again.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    startMonitoringTheTurn()
                    session.watchPeek(settings)
                } else {
                    perfectPlusHandler.stopMonitoring()
                    session.stopWatchingPeek()
                }
            }
            .onDisappear(perform: stopSession)
            #if DEBUG
            .task(id: session.wantsPeekDemo && settings.livePeekEnabled) {
                await runPeekDemoIfNeeded()
            }
            #endif
    }

    #if DEBUG
    /// Types `123 + 456 =` once when a developer launch asked for a peek demo.
    ///
    /// Only compiled into Debug builds and only armed when the invocation URL carries
    /// `demo=peek`, so a release clip never types on its own.
    private func runPeekDemoIfNeeded() async {
        guard session.wantsPeekDemo, settings.livePeekEnabled else { return }
        // Let the live-settings fetch and peek reporter finish wiring first.
        try? await Task.sleep(for: .milliseconds(800))
        let steps: [() -> Void] = [
            { digitPressed("1") }, { digitPressed("2") }, { digitPressed("3") },
            { performOperation(.add) },
            { digitPressed("4") }, { digitPressed("5") }, { digitPressed("6") },
            { equals() }
        ]
        for step in steps {
            step()
            try? await Task.sleep(for: .milliseconds(350))
        }
        debugLog("🧪 Peek demo typed 123 + 456 =")
    }
    #endif

    /// Every touch on the calculator, keys included, reported so an armed Perfect Plus can
    /// hold the number back until the phone has been left alone. Recognised alongside the
    /// keys rather than instead of them, so the keypad still works normally.
    private var screenTouch: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in perfectPlusHandler.noteScreenTouch() }
    }

    private func startSession() {
        calc.forceCount = 0
        peek.performerID = session.performerID
        startMonitoringTheTurn()
        session.watchPeek(settings)
    }

    private func startMonitoringTheTurn() {
        perfectPlusHandler.startMonitoring(
            hapticsEnabled: settings.perfectPlusHapticsEnabled
        ) {
            calculatePerfectAddend()
        }
    }

    private func stopSession() {
        peek.flush(calc.display, enabled: settings.livePeekEnabled, suppressed: peekSuppressed)
        peek.stop()
        session.stopWatchingPeek()
        perfectPlusHandler.stopMonitoring()
        modeHideWorkItem?.cancel()
        // The override is good for one sitting only, so closing the calculator
        // hands the trick back to the performer's published settings.
        quickForce.reset()
    }

    /// Live peek must report the spectator's number, never the performer's own
    /// setup. The covert clock sequence types the force number straight onto the
    /// display, and Perfect Plus leaves a staged value there while the phone is
    /// turned away, so peek stays quiet through both.
    private var peekSuppressed: Bool {
        quickForce.isArmed || perfectPlusHandler.mode.keysAreInert
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
            perfectPlusMode: perfectPlusHandler.mode
        )
        reportPeek()
    }

    private func decimalPressed() {
        CalculatorOperations.decimalPressed(state: &calc, perfectPlusMode: perfectPlusHandler.mode)
        reportPeek()
    }

    private func backspace() {
        CalculatorOperations.backspace(state: &calc, perfectPlusMode: perfectPlusHandler.mode)
        reportPeek()
    }

    /// Clear is the way out of an armed clock, the same way it backs out of Perfect Plus.
    /// An override already committed survives it, so a spectator clearing the display
    /// cannot undo the setup.
    private func clearAll() {
        quickForce.cancel()
        resetEntry()
        // Nothing was finished, but the number is gone, so whatever comes next belongs
        // beside it rather than on top of it.
        peek.beginNewEntry()
    }

    private func resetEntry() {
        CalculatorOperations.clearAll(state: &calc, perfectPlusHandler: perfectPlusHandler)
    }

    private func toggleSign() {
        CalculatorOperations.toggleSign(state: &calc, perfectPlusMode: perfectPlusHandler.mode)
        reportPeek()
    }

    /// Changes Force versus Date/Time for this clip session only. The performer's
    /// published settings are untouched.
    private func toggleMode() {
        settings.magicTrickMode = settings.magicTrickMode == .forceNumber ? .exactDateTime : .forceNumber
        scheduleModeHide()
    }

    private func performOperation(_ op: CalculatorOperation) {
        // Read before anything moves: finishing a pending sum replaces the display with
        // the running total, and the performer wants the number the spectator typed.
        let typed = calc.display
        // An operator pressed part-way through an entry finishes the sum on the go first,
        // so the display carries the running total into the next operation.
        if op != .percent,
           CalculatorOperations.shouldFinishPendingSum(calc, perfectPlusMode: perfectPlusHandler.mode) {
            evaluate()
        }
        CalculatorOperations.performOperation(
            op,
            state: &calc,
            settings: settings,
            perfectPlusHandler: perfectPlusHandler
        )
        closePeek(typed, with: op.peekSymbol)
    }

    private func equals() {
        // Mid-sequence, equals commits the typed force number instead of calculating.
        if quickForce.consumeEquals(display: calc.display) { return }
        let typed = calc.display
        evaluate()
        // The number the spectator pressed equals on, then the answer they were shown,
        // which is a new entry of its own.
        closePeek(typed, with: "=")
        reportPeek()
    }

    /// The calculation itself, with no reporting. The callers decide what the performer
    /// is told, because an operator that quietly finishes a pending sum should not put
    /// the running total on the performer's screen as if the spectator had typed it.
    private func evaluate() {
        CalculatorOperations.equals(
            state: &calc,
            force: force,
            countActivation: quickForce.countsActivation(settings: settings),
            perfectPlusHandler: perfectPlusHandler
        )
    }

    private func closePeek(_ value: String, with op: String) {
        peek.close(
            value,
            with: op,
            enabled: settings.livePeekEnabled,
            suppressed: peekSuppressed
        )
    }

    private func calculatePerfectAddend() {
        perfectPlusHandler.calculatePerfectAddend(state: &calc, force: force)
    }
}
