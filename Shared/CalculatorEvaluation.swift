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
        plusPerfectMode: inout PlusPerfectState,
        savedNumberForPlusPerfect: inout Double,
        plusPerfectHandler: PlusPerfectHandler,
        equalsAction: () -> Void
    ) {
        if armPlusPerfect(
            op,
            display: display,
            lastOperationWasEquals: &lastOperationWasEquals,
            settings: settings,
            plusPerfectMode: &plusPerfectMode,
            savedNumberForPlusPerfect: &savedNumberForPlusPerfect,
            plusPerfectHandler: plusPerfectHandler
        ) {
            return
        }
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
        plusPerfectMode: inout PlusPerfectState,
        lastOperation: inout CalculatorOperation?,
        lastOperand: inout Double
    ) {
        if plusPerfectMode == .calculated {
            showPlusPerfectResult(display: &display, settings: settings, plusPerfectMode: &plusPerfectMode)
            lastOperationWasEquals = false
            return
        }
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

    private static func armPlusPerfect(
        _ op: CalculatorOperation,
        display: String,
        lastOperationWasEquals: inout Bool,
        settings: CalculatorSettings,
        plusPerfectMode: inout PlusPerfectState,
        savedNumberForPlusPerfect: inout Double,
        plusPerfectHandler: PlusPerfectHandler
    ) -> Bool {
        let shouldArm = PlusPerfectMath.shouldArm(
            plusPerfectEnabled: settings.plusPerfectEnabled,
            isAdd: op == .add,
            isUpsideDown: plusPerfectHandler.isUpsideDown
        )
        guard shouldArm else { return false }
        let currentNumber = CalculatorFormatter.parseDisplay(display)
        savedNumberForPlusPerfect = currentNumber
        plusPerfectHandler.savedNumber = currentNumber
        plusPerfectHandler.mode = .upsideDown
        plusPerfectMode = .upsideDown
        lastOperationWasEquals = false
        return true
    }

    private static func showPlusPerfectResult(
        display: inout String,
        settings: CalculatorSettings,
        plusPerfectMode: inout PlusPerfectState
    ) {
        let forceNumber = settings.magicTrickMode == .forceNumber
            ? Double(settings.forceNumber)
            : Double(settings.getCurrentDateTimeNumber())
        display = CalculatorFormatter.formatResult(forceNumber)
        plusPerfectMode = .inactive
    }
}
