import Foundation

extension CalculatorOperations {
    /// True when an operator press has a sum under way that must be finished first, so the
    /// next operation starts from the running total.
    ///
    /// The callers settle this and press equals themselves before handing the keys over, so
    /// the two calls happen one after the other rather than one inside the other.
    public static func shouldFinishPendingSum(
        _ state: CalculatorState,
        perfectPlusMode: PerfectPlusState
    ) -> Bool {
        !perfectPlusMode.keysAreInert
            && state.operation != nil
            && (state.userIsTyping || state.operandStaged)
    }

    public static func performOperation(
        _ op: CalculatorOperation,
        state: inout CalculatorState,
        settings: CalculatorSettings,
        perfectPlusHandler: PerfectPlusHandler
    ) {
        // The keypad is inert while the phone is turned away, so a stray tap cannot disturb
        // the trick. Turning the phone back is the way out.
        guard !perfectPlusHandler.mode.keysAreInert else { return }
        if op == .percent {
            applyPercent(&state)
            perfectPlusHandler.reset()
            return
        }
        state.operandStaged = false
        state.previousNumber = CalculatorFormatter.parseDisplay(state.display)
        state.operation = op
        state.userIsTyping = false
        updatePerfectPlus(
            op,
            operand: state.previousNumber,
            settings: settings,
            perfectPlusHandler: perfectPlusHandler
        )
    }

    public static func equals(
        state: inout CalculatorState,
        force: ForceValues,
        countActivation: Bool = true,
        perfectPlusHandler: PerfectPlusHandler
    ) {
        guard !perfectPlusHandler.mode.keysAreInert else { return }
        if perfectPlusHandler.mode == .calculated {
            showPerfectPlusResult(&state, force: force, perfectPlusHandler: perfectPlusHandler)
            return
        }
        // The addition is finishing, so a turn of the phone afterwards must not arm anything.
        perfectPlusHandler.reset()
        state.operandStaged = false
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
        commitResult(
            calculated,
            state: &state,
            force: force,
            countActivation: countActivation
        )
    }

    private static func commitResult(
        _ calculated: Double,
        state: inout CalculatorState,
        force: ForceValues,
        countActivation: Bool
    ) {
        let result = countActivation
            ? applyForce(calculated: calculated, state: &state, force: force)
            : calculated
        state.display = CalculatorFormatter.formatResult(result)
        state.previousNumber = result
        storeRepeat(&state)
        // Cleared so the next bare equals repeats the last operand instead of
        // using the result as both sides. The repeat itself lives in lastOperation.
        state.operation = nil
        state.operandStaged = false
        state.userIsTyping = false
    }

    /// Percent of a pending sum, matching a four-function calculator.
    ///
    /// With add or subtract, the typed number is a percent of the left side
    /// (`200 + 10 %` stages 20). With multiply or divide, it is the typed number
    /// over 100 (`200 × 50 %` stages 0.5). Alone, the display itself is divided
    /// by 100. The pending operation stays so equals can finish it.
    private static func applyPercent(_ state: inout CalculatorState) {
        let typed = CalculatorFormatter.parseDisplay(state.display)
        let staged: Double
        switch state.operation {
        case .add, .subtract:
            staged = state.previousNumber * typed / 100
            state.operandStaged = true
        case .multiply, .divide:
            staged = typed / 100
            state.operandStaged = true
        case nil, .percent:
            staged = typed / 100
            state.operation = nil
            state.operandStaged = false
            state.previousNumber = staged
        }
        state.display = CalculatorFormatter.formatResult(staged)
        state.userIsTyping = false
    }

    // MARK: - Perfect Plus

    /// Plus leaves the trick pending so the phone can be turned over afterwards.
    /// Every other operation stands the trick down.
    private static func updatePerfectPlus(
        _ op: CalculatorOperation,
        operand: Double,
        settings: CalculatorSettings,
        perfectPlusHandler: PerfectPlusHandler
    ) {
        let shouldMarkPending = PerfectPlusMath.shouldMarkPendingAdd(
            perfectPlusEnabled: settings.perfectPlusEnabled,
            isAdd: op == .add
        )
        guard shouldMarkPending else {
            if op == .add {
                debugLog("🎭 Perfect Plus: plus pressed but the setting is off, adding normally")
            }
            perfectPlusHandler.reset()
            return
        }
        perfectPlusHandler.markPendingAdd(operand: operand)
    }

    /// Lands the reveal as an ordinary finished calculation. The pending add has to go with
    /// it: left in place, a second equals would add the saved number to the force and carry
    /// the display off the number the spectator was just shown. The activation count starts
    /// again too, so the keys that follow the reveal are honest ones.
    private static func showPerfectPlusResult(
        _ state: inout CalculatorState,
        force: ForceValues,
        perfectPlusHandler: PerfectPlusHandler
    ) {
        // The number the addend was built from, not a fresh reading of it. In Date and Time
        // mode the clock moves on, and landing somewhere else would leave the spectator with
        // a sum that does not add up. Read before the reset, which drops it.
        let forcedNumber = Double((perfectPlusHandler.frozenForce ?? force).number)
        state = CalculatorState()
        state.display = CalculatorFormatter.formatResult(forcedNumber)
        state.previousNumber = forcedNumber
        perfectPlusHandler.reset()
    }
}
