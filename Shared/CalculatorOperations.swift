import Foundation

public enum PlusPerfectState {
    case inactive
    case activated
    case waitingForFlip
    case upsideDown
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
        if plusPerfectMode == .upsideDown { return }
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
        if plusPerfectMode == .upsideDown || display.contains(".") { return }
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
        if plusPerfectMode == .upsideDown { return }
        let cleaned = display.replacingOccurrences(of: ",", with: "")
        if cleaned.count > 1 {
            display = CalculatorFormatter.formatDisplay(String(cleaned.dropLast()))
        } else {
            display = "0"
            userIsTyping = false
        }
    }

    public static func toggleSign(display: inout String, plusPerfectMode: PlusPerfectState) {
        if plusPerfectMode == .upsideDown || display == "0" { return }
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
        plusPerfectMode: inout PlusPerfectState,
        savedNumberForPlusPerfect: inout Double,
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
        plusPerfectMode = .inactive
        savedNumberForPlusPerfect = 0
        lastOperationWasEquals = false
        lastOperation = nil
        lastOperand = 0
    }
}
