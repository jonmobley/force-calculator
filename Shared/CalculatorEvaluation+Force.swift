import Foundation

extension CalculatorOperations {
    static func assignOperands(
        display: String,
        currentNumber: inout Double,
        previousNumber: inout Double,
        operation: CalculatorOperation?,
        lastOperand: Double
    ) {
        if operation == nil {
            previousNumber = CalculatorFormatter.parseDisplay(display)
            currentNumber = lastOperand
        } else {
            currentNumber = CalculatorFormatter.parseDisplay(display)
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

    static func applyForce(
        calculated: Double,
        forceCount: inout Int,
        lastMinuteChecked: inout Int?,
        hasUpdatedForMinuteChange: inout Bool,
        settings: CalculatorSettings,
        operation: inout CalculatorOperation?
    ) -> Double {
        let willForce = forceCount + 1 >= settings.activationCount
        let forceValue = willForce
            ? forceValue(
                settings: settings,
                lastMinuteChecked: &lastMinuteChecked,
                hasUpdatedForMinuteChange: &hasUpdatedForMinuteChange
            )
            : calculated
        let step = ForceActivation.advance(
            calculated: calculated,
            forceCount: forceCount,
            activationCount: settings.activationCount,
            forceValue: forceValue
        )
        forceCount = step.forceCount
        if step.didForce { operation = nil }
        return step.result
    }

    static func storeRepeat(
        operation: CalculatorOperation?,
        currentNumber: Double,
        lastOperation: inout CalculatorOperation?,
        lastOperand: inout Double
    ) {
        guard operation != nil else { return }
        lastOperation = operation
        lastOperand = currentNumber
    }

    // MARK: - Force value

    private static func forceValue(
        settings: CalculatorSettings,
        lastMinuteChecked: inout Int?,
        hasUpdatedForMinuteChange: inout Bool
    ) -> Double {
        if settings.magicTrickMode == .forceNumber {
            return Double(settings.forceNumber)
        }
        noteMinuteChange(
            lastMinuteChecked: &lastMinuteChecked,
            hasUpdatedForMinuteChange: &hasUpdatedForMinuteChange
        )
        return Double(settings.getCurrentDateTimeNumber())
    }

    private static func noteMinuteChange(
        lastMinuteChecked: inout Int?,
        hasUpdatedForMinuteChange: inout Bool
    ) {
        let currentMinute = Calendar.current.component(.minute, from: Date())
        if lastMinuteChecked == nil {
            lastMinuteChecked = currentMinute
        } else if !hasUpdatedForMinuteChange && currentMinute != lastMinuteChecked {
            hasUpdatedForMinuteChange = true
        }
    }
}
