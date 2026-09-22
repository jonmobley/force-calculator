import Foundation

extension CalculatorOperations {
    public static func performOperation(
        _ op: CalculatorOperation,
        display: inout String,
        previousNumber: inout Double,
        operation: inout CalculatorOperation?,
        userIsTyping: inout Bool,
        lastButtonWasOperation: inout Bool,
        lastOperationWasEquals: inout Bool,
        settings: CalculatorSettings,
        plusPerfectHandler: PlusPerfectHandler,
        equalsAction: () -> Void
    ) {
        // The keypad is inert while armed, so a stray tap cannot disturb the trick.
        // Clear is the way out.
        guard plusPerfectHandler.mode != .armed else { return }
        lastOperationWasEquals = false
        if operation != nil, userIsTyping {
            equalsAction()
        }
        previousNumber = CalculatorFormatter.parseDisplay(display)
        operation = op
        userIsTyping = false
        lastButtonWasOperation = true
        if op == .percent {
            display = CalculatorFormatter.formatResult(previousNumber / 100)
            operation = nil
        }
        updatePlusPerfect(
            op,
            operand: previousNumber,
            settings: settings,
            plusPerfectHandler: plusPerfectHandler
        )
    }

    public static func equals(
        display: inout String,
        currentNumber: inout Double,
        previousNumber: inout Double,
        operation: inout CalculatorOperation?,
        userIsTyping: inout Bool,
        lastButtonWasOperation: inout Bool,
        lastOperationWasEquals: inout Bool,
        forceCount: inout Int,
        lastMinuteChecked: inout Int?,
        hasUpdatedForMinuteChange: inout Bool,
        settings: CalculatorSettings,
        plusPerfectHandler: PlusPerfectHandler,
        lastOperation: inout CalculatorOperation?,
        lastOperand: inout Double
    ) {
        guard plusPerfectHandler.mode != .armed else { return }
        if plusPerfectHandler.mode == .calculated {
            showPlusPerfectResult(display: &display, settings: settings, plusPerfectHandler: plusPerfectHandler)
            lastOperationWasEquals = false
            return
        }
        // The addition is finishing, so a turn of the phone afterwards must not arm anything.
        plusPerfectHandler.reset()
        guard let currentOp = operation ?? lastOperation else {
            lastOperationWasEquals = true
            return
        }
        if currentOp == .percent { return }
        assignOperands(
            display: display,
            currentNumber: &currentNumber,
            previousNumber: &previousNumber,
            operation: operation,
            lastOperand: lastOperand
        )
        guard let calculated = evaluate(currentOp, previous: previousNumber, current: currentNumber) else {
            display = "Error"
            return
        }
        commitResult(
            calculated,
            display: &display,
            currentNumber: currentNumber,
            previousNumber: &previousNumber,
            operation: &operation,
            userIsTyping: &userIsTyping,
            lastButtonWasOperation: &lastButtonWasOperation,
            lastOperationWasEquals: &lastOperationWasEquals,
            forceCount: &forceCount,
            lastMinuteChecked: &lastMinuteChecked,
            hasUpdatedForMinuteChange: &hasUpdatedForMinuteChange,
            settings: settings,
            lastOperation: &lastOperation,
            lastOperand: &lastOperand
        )
    }

    private static func commitResult(
        _ calculated: Double,
        display: inout String,
        currentNumber: Double,
        previousNumber: inout Double,
        operation: inout CalculatorOperation?,
        userIsTyping: inout Bool,
        lastButtonWasOperation: inout Bool,
        lastOperationWasEquals: inout Bool,
        forceCount: inout Int,
        lastMinuteChecked: inout Int?,
        hasUpdatedForMinuteChange: inout Bool,
        settings: CalculatorSettings,
        lastOperation: inout CalculatorOperation?,
        lastOperand: inout Double
    ) {
        let result = applyForce(
            calculated: calculated,
            forceCount: &forceCount,
            lastMinuteChecked: &lastMinuteChecked,
            hasUpdatedForMinuteChange: &hasUpdatedForMinuteChange,
            settings: settings,
            operation: &operation
        )
        display = CalculatorFormatter.formatResult(result)
        previousNumber = result
        storeRepeat(
            operation: operation,
            currentNumber: currentNumber,
            lastOperation: &lastOperation,
            lastOperand: &lastOperand
        )
        if forceCount == 0 { operation = nil }
        userIsTyping = false
        lastButtonWasOperation = false
        lastOperationWasEquals = true
    }

    // MARK: - Plus Perfect

    /// Plus leaves the trick pending so the phone can be turned over afterwards.
    /// Every other operation stands the trick down.
    private static func updatePlusPerfect(
        _ op: CalculatorOperation,
        operand: Double,
        settings: CalculatorSettings,
        plusPerfectHandler: PlusPerfectHandler
    ) {
        let shouldMarkPending = PlusPerfectMath.shouldMarkPendingAdd(
            plusPerfectEnabled: settings.plusPerfectEnabled,
            isAdd: op == .add
        )
        guard shouldMarkPending else {
            plusPerfectHandler.reset()
            return
        }
        plusPerfectHandler.markPendingAdd(operand: operand)
    }

    private static func showPlusPerfectResult(
        display: inout String,
        settings: CalculatorSettings,
        plusPerfectHandler: PlusPerfectHandler
    ) {
        let forceNumber = settings.magicTrickMode == .forceNumber
            ? Double(settings.forceNumber)
            : Double(settings.getCurrentDateTimeNumber())
        display = CalculatorFormatter.formatResult(forceNumber)
        plusPerfectHandler.reset()
    }
}
