import SwiftUI
import UIKit

/// The calculator screen shared by the host app and the App Clip. Any change to what
/// the user sees or what a key does lives here, so the two targets cannot fall out
/// of step.
///
/// Two very small differences are the caller's job:
///
/// - `onDismiss` — the host offers a way back to the settings menu; the clip has no
///   menu to return to and passes nil, which hides the button entirely.
/// - `peekReporter` — the clip pipes the spectator's keystrokes to the peek service;
///   the host does not, since peek is a one-way spectator-to-performer feed.
///
/// Everything else — layout, C/AC behaviour, live reactions to setting changes, the
/// motion sensor, the mode badge — is driven from the shared `CalculatorSession`
/// this view owns.
public struct CalculatorViewRoot: View {
    @StateObject private var session: CalculatorSession
    @ObservedObject private var settings: CalculatorSettings
    @Environment(\.scenePhase) private var scenePhase
    private let onDismiss: (() -> Void)?
    private let demoRequested: Bool

    /// - Parameters:
    ///   - settings: The calculator settings this session should read from and write
    ///     mode toggles into. Held by the shared session by strong reference; the
    ///     parent view is expected to keep it alive for the lifetime of the screen.
    ///   - peekReporter: Optional. The clip creates one and passes it; the host
    ///     leaves it nil, so no keystrokes are reported.
    ///   - onDismiss: Optional. When supplied, the readout shows the dismiss control
    ///     and calls this on tap. Nil hides the control (clip's case). The shared
    ///     view wraps the closure to swallow presses while Perfect Plus holds the
    ///     keys, so a spectator's stray tap cannot leave the calculator.
    ///   - onSpectatorEntry: Optional. The host passes one so the earpiece voice can
    ///     say each number the spectator finishes; the clip leaves it nil.
    ///   - demoRequested: Debug-only opt-in from the clip's `demo=peek` invocation
    ///     URL. When true and live peek is on, types a short sum once so hardware
    ///     verification of the peek pipe does not need fingers. Ignored in Release.
    public init(
        settings: CalculatorSettings,
        peekReporter: PeekReporter? = nil,
        onDismiss: (() -> Void)? = nil,
        onSpectatorEntry: ((SpectatorEntry) -> Void)? = nil,
        demoRequested: Bool = false
    ) {
        self.settings = settings
        self.onDismiss = onDismiss
        self.demoRequested = demoRequested
        let session = CalculatorSession(settings: settings, peekReporter: peekReporter)
        session.onSpectatorEntry = onSpectatorEntry
        _session = StateObject(wrappedValue: session)
    }

    public var body: some View {
        calculator
            .background(Color.black.ignoresSafeArea())
            .simultaneousGesture(screenTouch)
            .onAppear {
                session.onAppear()
                // A spectator-facing calculator must not dim mid-trick. The idle
                // timer is disabled for as long as this screen is up and active.
                setIdleTimerDisabled(true)
            }
            .onDisappear {
                session.onDisappear()
                setIdleTimerDisabled(false)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    session.onSceneActivated()
                    setIdleTimerDisabled(true)
                } else {
                    session.onSceneDeactivated()
                    // The system ignores the flag while backgrounded; resetting is
                    // defensive so a later screen does not inherit a stuck awake.
                    setIdleTimerDisabled(false)
                }
            }
            // The host lets the performer toggle haptics from the settings menu, and
            // the clip fetches the performer's live settings after the calculator is
            // already up. Either way, the vibration has to change its mind to match.
            .onChange(of: settings.perfectPlusHapticsEnabled) { _, _ in
                session.hapticsSettingChanged()
            }
            // Peek may be switched on with the calculator already in front of the
            // spectator. No-op on the host, since it has no reporter.
            .onChange(of: settings.livePeekEnabled) { _, enabled in
                if enabled { session.livePeekTurnedOn() }
            }
            .modifier(PeekDemoModifier(demoRequested: demoRequested, session: session, settings: settings))
    }

    /// Keeps the screen from dimming while the calculator is the active foreground
    /// screen. Shared by host and clip so a handed-over phone stays lit either way.
    private func setIdleTimerDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    private var calculator: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                CalculatorReadout(
                    display: session.calc.expressionDisplay,
                    geometry: geometry,
                    themeColor: settings.buttonTheme.color,
                    showForceNumber: session.showForceNumber,
                    showModeText: session.showModeText,
                    modeName: session.modeName,
                    forcedNumber: session.force.number,
                    onDismiss: guardedDismiss,
                    onQuickEntry: session.toggleQuickEntry,
                    quickEntryStage: session.quickForce.stage,
                    onToggleMode: session.toggleMode,
                    onRevealMode: session.revealMode
                )
                CalculatorKeypad(
                    settings: settings,
                    showForceNumber: Binding(
                        get: { session.showForceNumber },
                        set: { session.showForceNumber = $0 }
                    ),
                    digitAction: session.digitPressed,
                    decimalAction: session.decimalPressed,
                    backspaceAction: session.backspace,
                    clearAction: session.clear,
                    toggleSignAction: session.toggleSign,
                    operationAction: session.performOperation,
                    equalsAction: session.equals
                )
            }
        }
    }

    /// Every touch on the calculator, keys included, reported so an armed Perfect Plus
    /// can hold the number back until the phone has been left alone. Recognised
    /// alongside the keys rather than instead of them, so the keypad still works.
    private var screenTouch: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in session.noteScreenTouch() }
    }

    /// Wraps the caller's dismiss so a spectator's stray press while the phone is
    /// turned away cannot leave the calculator. Nil when no dismiss was offered, so
    /// the readout hides the button entirely on the clip.
    private var guardedDismiss: (() -> Void)? {
        guard let onDismiss else { return nil }
        return { [session] in
            if session.perfectPlusHoldsTheKeys { return }
            onDismiss()
        }
    }
}

/// Debug-only peek-verification helper.
///
/// A developer launch of the clip can carry `demo=peek`, which sets `demoRequested`
/// through to here. Once live peek is on the demo types `123 + 456 =` through the
/// same session methods a fingered spectator would, so the peek pipe can be verified
/// on real hardware without pressing keys. In Release the whole thing compiles out.
private struct PeekDemoModifier: ViewModifier {
    let demoRequested: Bool
    let session: CalculatorSession
    let settings: CalculatorSettings

    func body(content: Content) -> some View {
        #if DEBUG
        content.task(id: demoRequested && settings.livePeekEnabled) {
            await runIfReady()
        }
        #else
        content
        #endif
    }

    #if DEBUG
    private func runIfReady() async {
        guard demoRequested, settings.livePeekEnabled else { return }
        // Let the live-settings fetch and peek reporter finish wiring first.
        try? await Task.sleep(for: .milliseconds(800))
        let steps: [() -> Void] = [
            { session.digitPressed("1") },
            { session.digitPressed("2") },
            { session.digitPressed("3") },
            { session.performOperation(.add) },
            { session.digitPressed("4") },
            { session.digitPressed("5") },
            { session.digitPressed("6") },
            { session.equals() }
        ]
        for step in steps {
            step()
            try? await Task.sleep(for: .milliseconds(350))
        }
        debugLog("🧪 Peek demo typed 123 + 456 =")
    }
    #endif
}
