import Foundation

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
