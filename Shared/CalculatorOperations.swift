import Foundation

public enum PerfectPlusState {
    case inactive
    /// Plus is pending as an ordinary addition. Turning the phone over now arms the trick.
    case pendingAdd
    /// The phone was turned over while plus was pending; the addend is not on the display yet.
    case armed
    /// The addend is on the display while the phone is still turned away, so it is already
    /// there the moment the phone comes back.
    case staged
    case calculated

    /// Whether the keypad is dead.
    ///
    /// It is for as long as the phone is turned away from the performer. The trick is run
    /// with a hand wrapped round the glass, which is exactly where stray presses land, and
    /// one landing now would either stand the trick down or wipe the staged addend.
    public var keysAreInert: Bool {
        self == .armed || self == .staged
    }
}

public enum CalculatorOperation {
    case add, subtract, multiply, divide, percent

    /// The glyph on the key, for the performer's read-out of what the spectator pressed.
    /// Matches the keypad rather than ASCII, so the transcript reads like the calculator.
    public var peekSymbol: String {
        switch self {
        case .add: return "+"
        case .subtract: return "−"
        case .multiply: return "×"
        case .divide: return "÷"
        case .percent: return "%"
        }
    }
}

/// Key handling shared by the host calculator and the App Clip.
public struct CalculatorOperations {
    public static func digitPressed(
        _ digit: String,
        state: inout CalculatorState,
        perfectPlusMode: PerfectPlusState
    ) {
        if perfectPlusMode.keysAreInert { return }
        if state.operandStaged {
            state.operandStaged = false
            state.userIsTyping = false
        }
        let digitCount = state.display.filter { $0.isNumber }.count
        if state.userIsTyping {
            guard digitCount < 9 else { return }
            state.display = CalculatorFormatter.formatDisplay(state.display + digit)
        } else {
            state.display = digit
            state.userIsTyping = true
        }
    }

    public static func decimalPressed(
        state: inout CalculatorState,
        perfectPlusMode: PerfectPlusState
    ) {
        if perfectPlusMode.keysAreInert || state.display.contains(".") { return }
        if state.operandStaged {
            state.operandStaged = false
            state.userIsTyping = false
        }
        if state.userIsTyping {
            state.display += "."
        } else {
            state.display = "0."
            state.userIsTyping = true
        }
    }

    public static func backspace(
        state: inout CalculatorState,
        perfectPlusMode: PerfectPlusState
    ) {
        if perfectPlusMode.keysAreInert { return }
        // A pending operator with no second operand yet (`10+`): erase the operator
        // and leave the left-hand number. Typing digits of the right side falls through
        // to ordinary digit deletion below.
        if state.operation != nil, !state.userIsTyping, !state.operandStaged {
            state.operation = nil
            state.display = CalculatorFormatter.formatResult(state.previousNumber)
            state.previousNumber = 0
            return
        }
        if state.operandStaged {
            state.operandStaged = false
            state.userIsTyping = true
        }
        let cleaned = state.display.replacingOccurrences(of: ",", with: "")
        if cleaned.count > 1 {
            state.display = CalculatorFormatter.formatDisplay(String(cleaned.dropLast()))
        } else {
            // Last digit of the right-hand entry: drop back to `10+` so another
            // backspace can clear the operator next.
            state.display = "0"
            state.userIsTyping = false
        }
    }

    public static func toggleSign(
        state: inout CalculatorState,
        perfectPlusMode: PerfectPlusState
    ) {
        if perfectPlusMode.keysAreInert || state.display == "0" { return }
        if state.display.hasPrefix("-") {
            state.display.removeFirst()
        } else {
            state.display = "-" + state.display
        }
        state.display = CalculatorFormatter.formatDisplay(state.display)
    }

    /// Clears the entry on the display, leaving any calculation under way in place.
    public static func clearEntry(
        state: inout CalculatorState,
        perfectPlusMode: PerfectPlusState
    ) {
        if perfectPlusMode.keysAreInert { return }
        state.display = "0"
        state.userIsTyping = false
        state.operandStaged = false
    }

    /// Clears the whole session, including the force count and any pending trick.
    ///
    /// Inert while the phone is turned away, like the rest of the keys. The trick is run with
    /// the phone on its face and a hand wrapped round the glass, which is exactly when a stray
    /// press lands, and clear was the only key still live enough to stand the trick down.
    /// Nothing is stranded by this: turning the phone back always hands the keys back.
    public static func clearAll(
        state: inout CalculatorState,
        perfectPlusHandler: PerfectPlusHandler
    ) {
        if perfectPlusHandler.mode.keysAreInert { return }
        state = CalculatorState()
        perfectPlusHandler.reset()
    }
}
