import Combine
import UIKit

/// Taps a peeked number out in haptics so the performer can read it without
/// looking at the screen.
///
/// Each digit is felt as a run of light taps counting it out, one to nine. Zero
/// has no count to give, so it is a single firm tap that stands apart from a light
/// one. A longer gap separates the digits, so `1,204` is felt as: tap · pause ·
/// tap-tap · pause · firm · pause · tap-tap-tap-tap. Grouping commas, the sign and
/// any decimal point are skipped; only the digits are tapped.
final class PeekHaptics: ObservableObject {
    /// One digit's worth of taps.
    enum DigitPulse: Equatable {
        /// A digit 1...9, felt as that many light taps.
        case count(Int)
        /// Zero, felt as a single firm tap.
        case zero
    }

    /// Gap between the light taps within a single digit.
    private let pulseGap: TimeInterval = 0.22
    /// Longer gap between digits, so their counts stay separable.
    private let digitGap: TimeInterval = 0.6

    private let lightTap = UIImpactFeedbackGenerator(style: .light)
    private let firmTap = UIImpactFeedbackGenerator(style: .heavy)
    private var scheduled: [DispatchWorkItem] = []

    /// Decodes a display string into one entry per digit.
    ///
    /// Pure, so the mapping from digits to pulses can be tested without hardware.
    static func plan(for value: String) -> [DigitPulse] {
        value.compactMap { character in
            guard let digit = character.wholeNumberValue, (0...9).contains(digit) else {
                return nil
            }
            return digit == 0 ? .zero : .count(digit)
        }
    }

    /// Taps out `value`, cancelling anything already playing.
    func play(_ value: String) {
        cancel()
        lightTap.prepare()
        firmTap.prepare()

        var delay: TimeInterval = 0
        for digit in Self.plan(for: value) {
            switch digit {
            case .zero:
                schedule(at: delay, firm: true)
                delay += pulseGap
            case .count(let times):
                for _ in 0..<times {
                    schedule(at: delay, firm: false)
                    delay += pulseGap
                }
            }
            delay += digitGap
        }
    }

    /// Stops a playback in progress. Called when the reveal is no longer on screen.
    func cancel() {
        scheduled.forEach { $0.cancel() }
        scheduled.removeAll()
    }

    // MARK: - Helpers

    private func schedule(at delay: TimeInterval, firm: Bool) {
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let generator = firm ? self.firmTap : self.lightTap
            generator.impactOccurred(intensity: firm ? 1.0 : 0.8)
            generator.prepare()
        }
        scheduled.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}
