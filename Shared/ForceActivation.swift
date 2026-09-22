import Foundation

/// What the next equals press should land on, and how many presses it takes.
///
/// Resolved once per press and handed to everything that needs an answer, so the
/// activation counter, the Plus Perfect addend and the equals-key peek cannot
/// disagree about which number is in play.
public struct ForceValues: Equatable {
    /// The number equals will land on.
    public let number: Int
    /// How many equals presses it takes to get there.
    public let activationCount: Int

    public init(number: Int, activationCount: Int) {
        self.number = number
        self.activationCount = activationCount
    }
}

/// Outcome of one equals press in the force sequence.
public struct ForceActivationResult: Equatable {
    /// Value that should appear on the display.
    public let result: Double
    /// Equals-press count after this press. Zero after the force fires.
    public let forceCount: Int
    /// True when this press replaced the calculation with the force value.
    public let didForce: Bool

    public init(result: Double, forceCount: Int, didForce: Bool) {
        self.result = result
        self.forceCount = forceCount
        self.didForce = didForce
    }
}

/// Counts equals presses and substitutes the force value only on the Nth press.
public enum ForceActivation {
    /// Advances the count. The display becomes `forceValue` only after
    /// `activationCount` presses, then the count resets to zero.
    public static func advance(
        calculated: Double,
        forceCount: Int,
        activationCount: Int,
        forceValue: Double
    ) -> ForceActivationResult {
        let nextCount = forceCount + 1
        guard nextCount >= activationCount else {
            return ForceActivationResult(result: calculated, forceCount: nextCount, didForce: false)
        }
        return ForceActivationResult(result: forceValue, forceCount: 0, didForce: true)
    }
}
