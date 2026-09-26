import Foundation

/// Everything one calculator session keeps between key presses.
///
/// Held as a single value so the shared key handling takes one binding rather than a dozen.
/// Separate bindings are what let a chained operator press lose its running total: two calls
/// writing the same session at once, and the second overwriting what the first worked out.
public struct CalculatorState {
    /// What the readout shows.
    public var display = "0"

    /// The operand being entered, or the result just shown.
    public var currentNumber: Double = 0

    /// The operand an unfinished operation is waiting on.
    public var previousNumber: Double = 0

    /// The operation waiting for its second operand.
    public var operation: CalculatorOperation?

    /// True while the display holds digits being typed rather than a result.
    public var userIsTyping = false

    /// True after percent has filled the second operand. The next digit replaces it;
    /// the next operator or equals finishes the sum it belongs to.
    public var percentReady = false

    /// Equals presses so far, counting toward the activation count.
    public var forceCount = 0

    /// The operation a bare equals press repeats.
    public var lastOperation: CalculatorOperation?

    /// The operand that repeat applies.
    public var lastOperand: Double = 0

    public init() {}

    /// What the readout shows: the live entry, or the unfinished sum so far.
    ///
    /// Operators live here rather than lighting up on the keypad. After `10` then `+`
    /// the display reads `10+`; once the next digits arrive it becomes `10+10`.
    public var expressionDisplay: String {
        guard let op = operation, op != .percent else { return display }
        let left = CalculatorFormatter.formatResult(previousNumber)
        let symbol = op.peekSymbol
        if userIsTyping || percentReady {
            return "\(left)\(symbol)\(display)"
        }
        return "\(left)\(symbol)"
    }
}
