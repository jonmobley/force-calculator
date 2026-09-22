import XCTest
import ForceShared

/// Holds the session the two `CalculatorView`s keep in `@State`, so a test can press keys
/// through the same shared handling the app and the App Clip use.
///
/// The thin glue each view wraps around `CalculatorOperations` is mirrored here rather than
/// reached into, because that glue is where a key press decides whether it belongs to the
/// calculator or to one of the tricks.
final class TestCalculator {
    private var calc = CalculatorState()

    private let settings = CalculatorSettings()
    private let plusPerfectHandler = PlusPerfectHandler()
    private let quickForce = QuickForceEntry()

    var display: String { calc.display }
    var plusPerfectMode: PlusPerfectState { plusPerfectHandler.mode }
    var quickEntryStage: QuickForceEntry.Stage { quickForce.stage }

    /// What the next equals press would force, resolved the way the views resolve it.
    var force: ForceValues { quickForce.values(settings: settings) }

    init(forceNumber: Int, activationCount: Int, plusPerfectEnabled: Bool = true) {
        settings.forceNumber = forceNumber
        settings.activationCount = activationCount
        settings.magicTrickMode = .forceNumber
        settings.plusPerfectEnabled = plusPerfectEnabled
    }

    /// Stands in for sums the spectator has already done, each of which moves the calculator
    /// one press closer to the activation count.
    func bankEqualsPresses(_ count: Int) {
        calc.forceCount = count
    }

    // MARK: - Keys

    func type(_ digits: String) {
        for digit in digits.map(String.init) {
            digitPressed(digit)
        }
    }

    private func digitPressed(_ digit: String) {
        if quickForce.consumeDigit(digit) {
            if !quickForce.isArmed { resetEntry() }
            return
        }
        CalculatorOperations.digitPressed(
            digit,
            state: &calc,
            plusPerfectMode: plusPerfectHandler.mode
        )
    }

    func press(_ op: CalculatorOperation) {
        if CalculatorOperations.shouldFinishPendingSum(calc, plusPerfectMode: plusPerfectHandler.mode) {
            equals()
        }
        CalculatorOperations.performOperation(
            op,
            state: &calc,
            settings: settings,
            plusPerfectHandler: plusPerfectHandler
        )
    }

    func equals() {
        if quickForce.consumeEquals(display: calc.display) { return }
        CalculatorOperations.equals(
            state: &calc,
            force: force,
            plusPerfectHandler: plusPerfectHandler
        )
    }

    func clearAll() {
        quickForce.cancel()
        resetEntry()
    }

    /// Mirrors a tap on the clock control in the readout.
    func tapClock() {
        resetEntry()
        quickForce.toggle()
    }

    /// Mirrors the calculator being closed, which is what ends a session override.
    func close() {
        quickForce.reset()
    }

    private func resetEntry() {
        CalculatorOperations.clearAll(state: &calc, plusPerfectHandler: plusPerfectHandler)
    }

    // MARK: - Plus Perfect

    /// Runs the trick through: the number, the plus, the turn of the phone, and the equals
    /// that shows the force.
    func reachTheForce(savedNumber: Int) {
        type(String(savedNumber))
        press(.add)
        turnPhoneOverAndBack()
        equals()
    }

    /// Stands in for the motion callback that fires when the phone comes back upright.
    func turnPhoneOverAndBack() {
        plusPerfectHandler.calculatePerfectAddend(state: &calc, force: force)
    }
}
