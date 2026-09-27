import XCTest
import ForceShared

/// Drives the shared `CalculatorSession` the way both `CalculatorView`s do, so a test
/// presses keys through exactly the same handler the host and the App Clip use.
///
/// The wrapper stays deliberately thin. Everything a key press actually decides —
/// digit routing through the clock sequence, Perfect Plus lockouts, C/AC swapping —
/// lives in `CalculatorSession`, and this file only translates test names into the
/// same calls the views make.
final class TestCalculator {
    private let session: CalculatorSession
    private let settings: CalculatorSettings

    var display: String { session.calc.display }
    var expressionDisplay: String { session.calc.expressionDisplay }
    var perfectPlusMode: PerfectPlusState { session.perfectPlusHandler.mode }
    var quickEntryStage: QuickForceEntry.Stage { session.quickForce.stage }

    /// What the next equals press would force, resolved the way the views resolve it.
    var force: ForceValues { session.force }

    init(forceNumber: Int, activationCount: Int, perfectPlusEnabled: Bool = true) {
        let settings = CalculatorSettings()
        settings.forceNumber = forceNumber
        settings.activationCount = activationCount
        settings.magicTrickMode = .forceNumber
        settings.perfectPlusEnabled = perfectPlusEnabled
        self.settings = settings
        self.session = CalculatorSession(settings: settings)
    }

    /// Stands in for sums the spectator has already done, each of which moves the calculator
    /// one press closer to the activation count.
    func bankEqualsPresses(_ count: Int) {
        session.calc.forceCount = count
    }

    // MARK: - Keys

    func type(_ digits: String) {
        for digit in digits.map(String.init) {
            session.digitPressed(digit)
        }
    }

    func press(_ op: CalculatorOperation) {
        session.performOperation(op)
    }

    func backspace() {
        session.backspace()
    }

    func equals() {
        session.equals()
    }

    func clearAll() {
        session.clear()
    }

    /// Mirrors a tap on the clock control in the readout.
    func tapClock() {
        session.toggleQuickEntry()
    }

    /// Mirrors the calculator being closed, which is what ends a session override.
    func close() {
        session.onDisappear()
    }

    // MARK: - Perfect Plus

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
        session.revealPerfectPlusAddend()
    }

    /// Stands in for the phone being turned over and then left alone: the number goes up
    /// behind the turn, with the keys still inert because the phone has not come back.
    func stageTheNumberBehindTheTurn(savedNumber: Int) {
        type(String(savedNumber))
        press(.add)
        session.revealPerfectPlusAddend()
        session.perfectPlusHandler.mode = .staged
    }

    /// Stands in for the turn back, which once the number is staged only hands the keys over.
    func turnPhoneBack() {
        session.perfectPlusHandler.mode = .calculated
    }
}
