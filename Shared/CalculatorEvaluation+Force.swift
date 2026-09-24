import Foundation

extension CalculatorOperations {
    /// Works out which two numbers the pending operation applies to. With no operation
    /// waiting, the press is a repeat of the last one, so the display becomes the left-hand
    /// operand and the stored operand comes back as the right.
    static func assignOperands(_ state: inout CalculatorState) {
        if state.operation == nil {
            state.previousNumber = CalculatorFormatter.parseDisplay(state.display)
            state.currentNumber = state.lastOperand
        } else {
            state.currentNumber = CalculatorFormatter.parseDisplay(state.display)
        }
    }

    static func evaluate(
        _ operation: CalculatorOperation,
        previous: Double,
        current: Double
    ) -> Double? {
        switch operation {
        case .add:
            return previous + current
        case .subtract:
            return previous - current
        case .multiply:
            return previous * current
        case .divide:
            return current == 0 ? nil : previous / current
        case .percent:
            return previous
        }
    }

    /// Advances the equals count and hands back either the honest result or the force.
    static func applyForce(
        calculated: Double,
        state: inout CalculatorState,
        force: ForceValues
    ) -> Double {
        let step = ForceActivation.advance(
            calculated: calculated,
            forceCount: state.forceCount,
            activationCount: force.activationCount,
            forceValue: Double(force.number)
        )
        state.forceCount = step.forceCount
        if step.didForce {
            // The number has to stay put if the spectator presses equals again.
            // Leaving the last operation in place would add to the force.
            state.operation = nil
            state.lastOperation = nil
        }
        return step.result
    }

    /// Remembers the operation and operand so a bare equals press can apply them again.
    static func storeRepeat(_ state: inout CalculatorState) {
        guard state.operation != nil else { return }
        state.lastOperation = state.operation
        state.lastOperand = state.currentNumber
    }
}
