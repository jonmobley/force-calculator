import Combine
import Foundation
import UIKit

/// Covert force entry driven from the clock button in the readout.
///
/// Tap the clock, type the new force number, press equals, then press a single digit
/// for the number of equals presses that should trigger it. Every step looks like
/// ordinary arithmetic from across a table, and the clock drops back to its resting
/// state as soon as the count lands.
///
/// What this sets is deliberately not part of `CalculatorSettings`, so it cannot reach
/// the app group or the config service, and `reset()` drops it when the calculator
/// closes. The sequence is for the minute before a trick; a lasting change still goes
/// through the settings form.
public final class QuickForceEntry: ObservableObject {
    /// How far through the clock-button sequence the performer is.
    public enum Stage: Equatable {
        case idle
        /// Clock armed. Digits type into the display as normal; equals captures them.
        case awaitingNumber
        /// Number captured. The next digit is the activation count.
        case awaitingActivation
    }

    /// Nine digits, matching the display's own typing cap. A wider value could only
    /// arrive from a leftover result, which is never what the performer meant to force.
    public static let maxForceNumber = 999_999_999

    /// The count is expressed in one keypress, so nine presses is the ceiling.
    public static let maxActivationCount = 9

    /// Badge text shown in place of the mode name while an override is in play.
    public static let overrideName = "Temporary"

    @Published public private(set) var stage: Stage = .idle

    /// Set once the whole sequence completes. Nil means the saved settings stand.
    @Published public private(set) var override: ForceValues?

    private var capturedNumber: Int?
    private let haptics = UIImpactFeedbackGenerator(style: .medium)

    /// Delay between the two pulses that confirm a committed override.
    private let commitPulseGap: TimeInterval = 0.12

    public init() {}

    /// True while the sequence is running, so the readout can show the clock's
    /// active state.
    public var isArmed: Bool { stage != .idle }

    // MARK: - Resolving

    /// The values the next equals press should use.
    ///
    /// An override wins outright, including over Date and Time mode: a number typed in
    /// by hand is an explicit instruction, and silently preferring the clock over it
    /// would leave the performer forcing something they did not ask for.
    public func values(settings: CalculatorSettings) -> ForceValues {
        override ?? ForceValues(
            number: settings.forcedNumber,
            activationCount: settings.activationCount
        )
    }

    /// Label for the covert mode badge, so a long press on the readout tells the
    /// performer whether they are on a temporary number or the saved one.
    public func modeName(settings: CalculatorSettings) -> String {
        override == nil ? settings.magicTrickMode.rawValue : Self.overrideName
    }

    // MARK: - Sequence

    /// Arms the sequence, or abandons one already under way.
    ///
    /// - Returns: The new stage, so the caller can tidy the display to match.
    @discardableResult
    public func toggle() -> Stage {
        if isArmed {
            cancel()
        } else {
            stage = .awaitingNumber
            haptics.prepare()
            haptics.impactOccurred(intensity: 0.4)
            debugLog("🕐 Quick force: armed")
        }
        return stage
    }

    /// Abandons a sequence under way. An override already committed stands, so the
    /// spectator pressing clear cannot undo the setup.
    public func cancel() {
        guard isArmed else { return }
        stage = .idle
        capturedNumber = nil
        debugLog("🕐 Quick force: cancelled")
    }

    /// Drops the override along with any sequence under way. Calling this when the
    /// calculator closes is what keeps the override to a single session.
    public func reset() {
        stage = .idle
        capturedNumber = nil
        override = nil
    }

    /// Takes a digit press when the sequence is waiting for the activation count.
    ///
    /// - Returns: True when the digit was consumed and must not reach the display.
    public func consumeDigit(_ digit: String) -> Bool {
        guard stage == .awaitingActivation else { return false }
        guard let number = capturedNumber,
              let count = Int(digit),
              (1...Self.maxActivationCount).contains(count) else {
            // Zero is a slip rather than a count, so the sequence keeps waiting instead
            // of committing a number of presses the performer cannot have intended.
            return true
        }
        commit(ForceValues(number: number, activationCount: count))
        return true
    }

    /// Takes an equals press when the sequence is under way.
    ///
    /// - Returns: True when equals was consumed and must not calculate.
    public func consumeEquals(display: String) -> Bool {
        switch stage {
        case .idle:
            return false
        case .awaitingNumber:
            capture(display: display)
            return true
        case .awaitingActivation:
            // Still short a count. Swallowing this stops a stray second press running
            // the calculation that the display only looks like it is holding.
            return true
        }
    }

    // MARK: - Steps

    private func capture(display: String) {
        let typed = CalculatorFormatter.parseDisplay(display)
        // Equals pressed before anything was typed, or on a result too wide to force.
        // Staying armed lets the performer simply type it again.
        guard typed >= 1, typed <= Double(Self.maxForceNumber) else { return }
        let number = Int(typed)
        capturedNumber = number
        stage = .awaitingActivation
        haptics.impactOccurred(intensity: 0.7)
        debugLog("🕐 Quick force: captured \(number), waiting for count")
    }

    private func commit(_ values: ForceValues) {
        override = values
        capturedNumber = nil
        stage = .idle
        playCommitPulse()
        debugLog("🕐 Quick force: \(values.number) on equals press \(values.activationCount)")
    }

    // MARK: - Haptics

    /// Two quick taps, so a committed override is unmistakable without looking down.
    private func playCommitPulse() {
        haptics.impactOccurred(intensity: 0.5)
        haptics.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + commitPulseGap) { [weak self] in
            self?.haptics.impactOccurred(intensity: 0.9)
        }
    }
}
