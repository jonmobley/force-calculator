import Combine
import Foundation
import SwiftUI

/// A number the spectator finished, handed to the host so the performer can hear it.
public enum SpectatorEntry: Equatable {
    /// A number they typed, closed by an operator or equals.
    case typed(String)
    /// The answer equals showed them.
    case answer(String)
}

/// The calculator's non-view state and key handling, shared by the host app and the
/// App Clip so the two targets cannot drift on behaviour.
///
/// Owns every piece of state a key press might touch (`calc`, `perfectPlusHandler`,
/// `quickForce`) and every glue rule that decides how a press is interpreted (the
/// clock override, the Perfect Plus lockout, the AC/C mode of the clear key). The
/// only target-specific concern is peek reporting, which is injected as an optional
/// `PeekReporter`: nil on the host, present on the clip. Every other decision is
/// identical on both.
///
/// Every call must happen on the main thread — the class touches SwiftUI's
/// `withAnimation`, dispatches to `DispatchQueue.main` for the mode-badge
/// countdown, and drives `@Published` state the views observe. Not annotated
/// `@MainActor` only so the test target (compiled without strict concurrency)
/// can drive it synchronously from XCTest methods.
public final class CalculatorSession: ObservableObject {
    /// The whole numeric session, published so the readout updates as keys land.
    @Published public var calc = CalculatorState()

    /// The equals key's ghost of the current force number, revealed by a long press.
    @Published public var showForceNumber = false

    /// The trailing mode badge that appears briefly after a reveal or mode change.
    @Published public var showModeText = false

    /// Whether the top-left key acts as "clear entry" this press or "clear all",
    /// mirroring the stock iOS calculator's C/AC behaviour.
    @Published public var hasEntryToClear = false

    public let perfectPlusHandler = PerfectPlusHandler()
    public let quickForce = QuickForceEntry()

    /// Optional peek pipe. The clip creates one and injects it; the host leaves it
    /// nil, since peek is a spectator-to-performer feed and the host never reports.
    public var peekReporter: PeekReporter?

    /// Host-only: told about each number the spectator finishes (never the performer's
    /// own setup), so the earpiece voice can say it. The clip leaves it nil.
    public var onSpectatorEntry: ((SpectatorEntry) -> Void)?

    private let settings: CalculatorSettings
    private var modeHideWorkItem: DispatchWorkItem?

    public init(settings: CalculatorSettings, peekReporter: PeekReporter? = nil) {
        self.settings = settings
        self.peekReporter = peekReporter
    }

    // MARK: - Derived state

    /// What equals will land on, resolved the way both targets resolve it.
    public var force: ForceValues { quickForce.values(settings: settings) }

    /// Label for the covert mode badge.
    public var modeName: String { quickForce.modeName(settings: settings) }

    /// True while the phone is turned away and every tap has to be a no-op. The keypad
    /// itself is already dead through `CalculatorOperations`, but the top-bar controls
    /// (clock, mode button, readout long-press, dismiss) run outside that path and would
    /// otherwise arm covert entry, flip the mode, reveal the badge, or leave the
    /// calculator on a spectator's stray press.
    public var perfectPlusHoldsTheKeys: Bool { perfectPlusHandler.mode.keysAreInert }

    /// Live peek must report the spectator's number, never the performer's own setup.
    /// The covert clock sequence types the force number straight onto the display, and
    /// Perfect Plus leaves a staged value there, so peek stays quiet through both. The
    /// staged value stays secret after the phone comes back, until the spectator types
    /// over it; reported, it would give the method away on the performer's screen.
    public var peekSuppressed: Bool {
        quickForce.isArmed
            || perfectPlusHandler.mode.keysAreInert
            || (perfectPlusHandler.mode == .calculated && calc.operandStaged)
    }

    // MARK: - Lifecycle

    /// Called from the view's `onAppear`. Zeroes the count for a fresh sitting and
    /// starts sampling the phone's attitude for Perfect Plus.
    public func onAppear() {
        debugLog("🧮 CalculatorSession: onAppear")
        calc.forceCount = 0
        startMonitoringTheTurn()
    }

    /// Called from the view's `onDisappear`. Flushes a pending peek report, stops the
    /// motion sensor, and hands the temporary force override back to the saved settings.
    public func onDisappear() {
        peekReporter?.flush(
            calc.display,
            enabled: settings.livePeekEnabled,
            suppressed: peekSuppressed
        )
        peekReporter?.stop()
        perfectPlusHandler.stopMonitoring()
        modeHideWorkItem?.cancel()
        // The override is good for one sitting only, so closing the calculator hands
        // the trick back to the saved settings.
        quickForce.reset()
    }

    /// Called when the app becomes active. Gravity is sampled ten times a second, which
    /// is worth nothing once the calculator is off screen and costs battery in a pocket.
    public func onSceneActivated() {
        startMonitoringTheTurn()
    }

    /// Called when the app leaves active. The motion sensor stops sampling, and any
    /// debounced peek report is flushed on the way out: iOS may suspend the process
    /// before the pending dispatch fires, and a digit sitting in that window would
    /// otherwise never reach the performer. The mode-badge hide is cancelled too, so
    /// it does not fire late after the scene has already gone away.
    public func onSceneDeactivated() {
        peekReporter?.flush(
            calc.display,
            enabled: settings.livePeekEnabled,
            suppressed: peekSuppressed
        )
        perfectPlusHandler.stopMonitoring()
        modeHideWorkItem?.cancel()
        modeHideWorkItem = nil
    }

    /// The performer's live settings can land after the calculator is already up, and
    /// the host lets the performer toggle haptics without dismissing the calculator, so
    /// both targets keep the vibration in step with the setting as it changes.
    public func hapticsSettingChanged() {
        perfectPlusHandler.hapticsEnabled = settings.perfectPlusHapticsEnabled
    }

    /// Live peek may be switched on with the spectator already calculating. Send
    /// whatever is on screen now rather than waiting for the next key.
    public func livePeekTurnedOn() {
        peekReporter?.flush(calc.display, enabled: true, suppressed: peekSuppressed)
    }

    // MARK: - Keys

    public func digitPressed(_ digit: String) {
        // The clock sequence claims the digit that sets the activation count, which
        // must not also land on the display. Finishing the sequence clears the number
        // the performer typed, leaving the calculator looking untouched.
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
        reportPeek()
    }

    public func decimalPressed() {
        CalculatorOperations.decimalPressed(state: &calc, perfectPlusMode: perfectPlusHandler.mode)
        if !perfectPlusHoldsTheKeys { hasEntryToClear = true }
        reportPeek()
    }

    public func backspace() {
        CalculatorOperations.backspace(state: &calc, perfectPlusMode: perfectPlusHandler.mode)
        if !perfectPlusHoldsTheKeys {
            hasEntryToClear = calc.display != "0" || calc.operation != nil
        }
        reportPeek()
    }

    public func toggleSign() {
        CalculatorOperations.toggleSign(state: &calc, perfectPlusMode: perfectPlusHandler.mode)
        reportPeek()
    }

    /// The single "clear" key.
    ///
    /// With the clock sequence armed, clear is the escape hatch: it always backs the
    /// sequence out entirely, so the performer has a reliable way to abandon a setup
    /// they no longer want. With the sequence idle, it delegates to `clearEntry` when
    /// there is a half-typed entry to wipe or `clearAll` otherwise — the same rule
    /// the stock iOS calculator uses to swap between C and AC.
    public func clear() {
        if quickForce.isArmed {
            clearAll()
        } else if hasEntryToClear {
            clearEntry()
        } else {
            clearAll()
        }
    }

    /// Clear is the way out of an armed clock, the same way it backs out of Perfect Plus.
    /// An override already committed survives it, so a spectator clearing the display
    /// cannot undo the setup.
    private func clearAll() {
        quickForce.cancel()
        resetEntry()
        // Nothing was finished, but the number is gone, so whatever comes next belongs
        // beside it rather than on top of it.
        peekReporter?.beginNewEntry()
    }

    private func resetEntry() {
        CalculatorOperations.clearAll(state: &calc, perfectPlusHandler: perfectPlusHandler)
        hasEntryToClear = false
    }

    private func clearEntry() {
        CalculatorOperations.clearEntry(state: &calc, perfectPlusMode: perfectPlusHandler.mode)
        hasEntryToClear = false
    }

    public func performOperation(_ op: CalculatorOperation) {
        // Read before anything moves: finishing a pending sum replaces the display with
        // the running total, and the performer wants the number the spectator typed.
        let typed = calc.display
        let typedIsSecret = peekSuppressed
        let typedSomething = calc.userIsTyping
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
        hasEntryToClear = false
        closePeek(typed, with: op.peekSymbol, suppressed: typedIsSecret)
        if typedSomething, !typedIsSecret { onSpectatorEntry?(.typed(typed)) }
    }

    public func equals() {
        // Mid-sequence, equals commits the typed force number instead of calculating.
        if quickForce.consumeEquals(display: calc.display) { return }
        let typed = calc.display
        // Read before evaluating: the Perfect Plus reveal resets the trick, which would
        // otherwise let the staged number through as if the spectator had typed it.
        let typedIsSecret = peekSuppressed
        let typedSomething = calc.userIsTyping
        evaluate()
        hasEntryToClear = false
        // The number the spectator pressed equals on, then the answer they were shown,
        // which is a new entry of its own.
        closePeek(typed, with: "=", suppressed: typedIsSecret)
        reportPeek()
        if let onSpectatorEntry, !typedIsSecret {
            if typedSomething { onSpectatorEntry(.typed(typed)) }
            if !peekSuppressed { onSpectatorEntry(.answer(calc.display)) }
        }
    }

    /// The calculation itself, with no reporting. Callers decide what the performer
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

    // MARK: - Top-bar controls

    /// Starts covert force entry, or abandons a sequence already running. The display
    /// is wiped either way, so the performer types into a clean readout and nothing
    /// is left sitting there if they back out.
    public func toggleQuickEntry() {
        if perfectPlusHoldsTheKeys { return }
        resetEntry()
        quickForce.toggle()
    }

    /// Steps to the next trick mode (Force, Date/Time, Special Day, then round again)
    /// for this session only. On the clip, the performer's published settings are
    /// untouched; on the host the local settings take the change and autosave picks it up.
    public func toggleMode() {
        if perfectPlusHoldsTheKeys { return }
        let modes = MagicTrickMode.allCases
        let index = modes.firstIndex(of: settings.magicTrickMode) ?? 0
        settings.magicTrickMode = modes[(index + 1) % modes.count]
        scheduleModeHide()
        debugLog("🔄 Mode toggled to: \(settings.magicTrickMode)")
    }

    /// Shows the hidden mode badge long enough to read.
    public func revealMode() {
        if perfectPlusHoldsTheKeys { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            showModeText = true
        }
        scheduleModeHide()
        debugLog("👁️ Mode revealed: \(settings.magicTrickMode)")
    }

    /// Restarts the auto-hide countdown so a mode change does not cut the reveal short.
    private func scheduleModeHide() {
        modeHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            withAnimation(.easeInOut(duration: 0.2)) {
                self?.showModeText = false
            }
        }
        modeHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + CalculatorReadout.modeRevealDuration,
            execute: workItem
        )
    }

    // MARK: - Perfect Plus

    /// Every touch on the calculator, keys included, reported so an armed Perfect Plus
    /// can hold the number back until the phone has been left alone.
    public func noteScreenTouch() {
        perfectPlusHandler.noteScreenTouch()
    }

    /// Stages the Perfect Plus addend on the display, exactly as the motion callback
    /// would after the turn. Exposed publicly so tests can drive the reveal without a
    /// physical turn of a phone.
    public func revealPerfectPlusAddend() {
        perfectPlusHandler.calculatePerfectAddend(state: &calc, force: force)
    }

    private func startMonitoringTheTurn() {
        perfectPlusHandler.startMonitoring(
            hapticsEnabled: settings.perfectPlusHapticsEnabled
        ) { [weak self] in
            self?.revealPerfectPlusAddend()
        }
    }

    // MARK: - Peek helpers

    private func reportPeek() {
        peekReporter?.report(
            calc.display,
            enabled: settings.livePeekEnabled,
            suppressed: peekSuppressed
        )
    }

    private func closePeek(_ value: String, with op: String, suppressed: Bool) {
        peekReporter?.close(
            value,
            with: op,
            enabled: settings.livePeekEnabled,
            suppressed: suppressed
        )
    }
}
