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
        display: inout String,
        userIsTyping: inout Bool,
        lastOperationWasEquals: inout Bool,
        plusPerfectMode: PlusPerfectState
    ) {
        lastOperationWasEquals = false
        if plusPerfectMode == .armed { return }
        let digitCount = display.filter { $0.isNumber }.count
        if userIsTyping {
            guard digitCount < 9 else { return }
            display = CalculatorFormatter.formatDisplay(display + digit)
        } else {
            display = digit
            userIsTyping = true
        }
    }

    public static func decimalPressed(
        display: inout String,
        userIsTyping: inout Bool,
        lastOperationWasEquals: inout Bool,
        plusPerfectMode: PlusPerfectState
    ) {
        lastOperationWasEquals = false
        if plusPerfectMode == .armed || display.contains(".") { return }
        if userIsTyping {
            display += "."
        } else {
            display = "0."
            userIsTyping = true
        }
    }

    public static func backspace(
        display: inout String,
        userIsTyping: inout Bool,
        plusPerfectMode: PlusPerfectState
    ) {
        if plusPerfectMode == .armed { return }
        let cleaned = display.replacingOccurrences(of: ",", with: "")
        if cleaned.count > 1 {
            display = CalculatorFormatter.formatDisplay(String(cleaned.dropLast()))
        } else {
            display = "0"
            userIsTyping = false
        }
    }

    public static func toggleSign(display: inout String, plusPerfectMode: PlusPerfectState) {
        if plusPerfectMode == .armed || display == "0" { return }
        if display.hasPrefix("-") {
            display.removeFirst()
        } else {
            display = "-" + display
        }
        display = CalculatorFormatter.formatDisplay(display)
    }

    public static func clearEntry(display: inout String, userIsTyping: inout Bool) {
        display = "0"
        userIsTyping = false
    }

    public static func clearAll(
        display: inout String,
        currentNumber: inout Double,
        previousNumber: inout Double,
        operation: inout CalculatorOperation?,
        userIsTyping: inout Bool,
        forceCount: inout Int,
        lastMinuteChecked: inout Int?,
        hasUpdatedForMinuteChange: inout Bool,
        plusPerfectHandler: PlusPerfectHandler,
        lastOperationWasEquals: inout Bool,
        lastOperation: inout CalculatorOperation?,
        lastOperand: inout Double
    ) {
        display = "0"
        currentNumber = 0
        previousNumber = 0
        operation = nil
        userIsTyping = false
        forceCount = 0
        lastMinuteChecked = nil
        hasUpdatedForMinuteChange = false
        plusPerfectHandler.reset()
        lastOperationWasEquals = false
        lastOperation = nil
        lastOperand = 0
    }
}
