import Foundation

extension CalculatorOperations {
    /// True when an operator press has a sum under way that must be finished first, so the
    /// next operation starts from the running total.
    ///
    /// The callers settle this and press equals themselves before handing the keys over, so
    /// the two calls happen one after the other rather than one inside the other.
    public static func shouldFinishPendingSum(
        _ state: CalculatorState,
        plusPerfectMode: PlusPerfectState
    ) -> Bool {
        plusPerfectMode != .armed && state.operation != nil && state.userIsTyping
    }

    public static func performOperation(
        _ op: CalculatorOperation,
        state: inout CalculatorState,
        settings: CalculatorSettings,
        plusPerfectHandler: PlusPerfectHandler
    ) {
        // The keypad is inert while armed, so a stray tap cannot disturb the trick.
        // Clear is the way out.
        guard plusPerfectHandler.mode != .armed else { return }
        state.previousNumber = CalculatorFormatter.parseDisplay(state.display)
        state.operation = op
        state.userIsTyping = false
        if op == .percent {
            state.display = CalculatorFormatter.formatResult(state.previousNumber / 100)
            state.operation = nil
        }
        updatePlusPerfect(
            op,
            operand: state.previousNumber,
            settings: settings,
            plusPerfectHandler: plusPerfectHandler
        )
    }

    public static func equals(
        state: inout CalculatorState,
        force: ForceValues,
        plusPerfectHandler: PlusPerfectHandler
    ) {
        guard plusPerfectHandler.mode != .armed else { return }
        if plusPerfectHandler.mode == .calculated {
            showPlusPerfectResult(&state, force: force, plusPerfectHandler: plusPerfectHandler)
            return
        }
        // The addition is finishing, so a turn of the phone afterwards must not arm anything.
        plusPerfectHandler.reset()
        guard let currentOp = state.operation ?? state.lastOperation else { return }
        if currentOp == .percent { return }
        assignOperands(&state)
        guard let calculated = evaluate(
            currentOp,
            previous: state.previousNumber,
            current: state.currentNumber
        ) else {
            state.display = "Error"
            return
        }
        commitResult(calculated, state: &state, force: force)
    }

    private static func commitResult(
        _ calculated: Double,
        state: inout CalculatorState,
        force: ForceValues
    ) {
        let result = applyForce(calculated: calculated, state: &state, force: force)
        state.display = CalculatorFormatter.formatResult(result)
        state.previousNumber = result
        storeRepeat(&state)
        if state.forceCount == 0 { state.operation = nil }
        state.userIsTyping = false
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

    /// Lands the reveal as an ordinary finished calculation. The pending add has to go with
    /// it: left in place, a second equals would add the saved number to the force and carry
    /// the display off the number the spectator was just shown. The activation count starts
    /// again too, so the keys that follow the reveal are honest ones.
    private static func showPlusPerfectResult(
        _ state: inout CalculatorState,
        force: ForceValues,
        plusPerfectHandler: PlusPerfectHandler
    ) {
        let forcedNumber = Double(force.number)
        state = CalculatorState()
        state.display = CalculatorFormatter.formatResult(forcedNumber)
        state.previousNumber = forcedNumber
        plusPerfectHandler.reset()
    }
}
