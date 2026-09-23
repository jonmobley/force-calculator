import Foundation
import UIKit

/// The two buzzes Perfect Plus gives the performer: one when the turn arms the trick, and a
/// firmer one when the addend is on the hidden display and the phone can be brought back.
///
/// The whole thing can be silenced. The buzz is felt by whoever is holding the phone, so a
/// performer who hands it to the spectator for the turn wants nothing to give the moment
/// away.
final class PerfectPlusHaptics {
    /// Delay between the two pulses of the armed confirmation.
    private let armedPulseGap: TimeInterval = 0.12

    private let generator = UIImpactFeedbackGenerator(style: .medium)

    /// Set from the performer's settings when monitoring starts.
    var isEnabled = true

    func prepare() {
        guard isEnabled else { return }
        generator.prepare()
    }

    /// Two quick taps, so an armed trick is distinguishable from an accidental knock.
    func playArmed() {
        guard isEnabled else { return }
        generator.impactOccurred(intensity: 0.5)
        generator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + armedPulseGap) { [weak self] in
            self?.generator.impactOccurred(intensity: 0.9)
        }
    }

    /// One firm tap: the number is up and the phone can be turned back.
    func playReveal() {
        guard isEnabled else { return }
        generator.impactOccurred(intensity: 1.0)
        generator.prepare()
    }
}
