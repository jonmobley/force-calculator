import Foundation

public enum PlusPerfectState {
    case inactive
    /// Plus is pending as an ordinary addition. Turning the phone over now arms the trick.
    case pendingAdd
    /// The phone was turned over while plus was pending; waiting for it to come back upright.
    case armed
    case calculated
}

public enum CalculatorOperation {
    case add, subtract, multiply, divide, percent
}

/// Key handling shared by the host calculator and the App Clip.
public struct CalculatorOperations {
    public static func digitPressed(
        _ digit: String,
        state: inout CalculatorState,
        plusPerfectMode: PlusPerfectState
    ) {
        if plusPerfectMode == .armed { return }
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
        plusPerfectMode: PlusPerfectState
    ) {
        if plusPerfectMode == .armed || state.display.contains(".") { return }
        if state.userIsTyping {
            state.display += "."
        } else {
            state.display = "0."
            state.userIsTyping = true
        }
    }

    public static func backspace(
        state: inout CalculatorState,
        plusPerfectMode: PlusPerfectState
    ) {
        if plusPerfectMode == .armed { return }
        let cleaned = state.display.replacingOccurrences(of: ",", with: "")
        if cleaned.count > 1 {
            state.display = CalculatorFormatter.formatDisplay(String(cleaned.dropLast()))
        } else {
            state.display = "0"
            state.userIsTyping = false
        }
    }

    public static func toggleSign(
        state: inout CalculatorState,
        plusPerfectMode: PlusPerfectState
    ) {
        if plusPerfectMode == .armed || state.display == "0" { return }
        if state.display.hasPrefix("-") {
            state.display.removeFirst()
        } else {
            state.display = "-" + state.display
        }
        state.display = CalculatorFormatter.formatDisplay(state.display)
    }

    /// Clears the entry on the display, leaving any calculation under way in place.
    public static func clearEntry(state: inout CalculatorState) {
        state.display = "0"
        state.userIsTyping = false
    }

    /// Clears the whole session, including the force count and any pending trick.
    public static func clearAll(
        state: inout CalculatorState,
        plusPerfectHandler: PlusPerfectHandler
    ) {
        state = CalculatorState()
        plusPerfectHandler.reset()
    }
}
