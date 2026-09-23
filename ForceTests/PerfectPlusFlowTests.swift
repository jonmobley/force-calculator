import XCTest
import ForceShared

/// Covers what the keypad does once a Perfect Plus reveal has landed. The tests in
/// `ForceLogicTests` check the decisions that lead up to the reveal; these press real keys
/// afterwards, because the state the reveal leaves behind is what the spectator gets to
/// play with.
final class PerfectPlusFlowTests: XCTestCase {
    private let forceNumber = 4_556_325

    func testRevealLeavesNoPendingAddBehind() {
        let calculator = TestCalculator(forceNumber: forceNumber, activationCount: 3)
        calculator.reachTheForce(savedNumber: 100)
        XCTAssertEqual(calculator.display, formatted(forceNumber))
        XCTAssertEqual(calculator.perfectPlusMode, .inactive)

        // A spectator tapping equals again must not carry the display off the force.
        calculator.equals()
        XCTAssertEqual(calculator.display, formatted(forceNumber))

        // Nor may a fresh sum pick up the number the plus was pressed on.
        calculator.type("7")
        calculator.press(.add)
        calculator.type("7")
        calculator.equals()
        XCTAssertEqual(calculator.display, "14")
    }

    /// The reveal is a force in its own right, so it has to spend the equals count rather
    /// than leave it part-way through and fire again on the spectator's next sum.
    func testRevealSpendsTheActivationCount() {
        let calculator = TestCalculator(forceNumber: forceNumber, activationCount: 3)
        calculator.bankEqualsPresses(2)

        calculator.reachTheForce(savedNumber: 100)
        XCTAssertEqual(calculator.display, formatted(forceNumber))

        calculator.type("5")
        calculator.press(.add)
        calculator.type("5")
        calculator.equals()
        XCTAssertEqual(calculator.display, "10")
    }

    /// The number is staged while the phone is still turned away, so the keypad has to stay
    /// dead until it comes back. A hand wrapped round the glass is exactly where stray
    /// presses land, and one landing now would type over the whole trick.
    func testStagedNumberSurvivesHandlingUntilThePhoneComesBack() {
        let calculator = TestCalculator(forceNumber: forceNumber, activationCount: 3)
        calculator.stageTheNumberBehindTheTurn(savedNumber: 100)
        let staged = calculator.display
        XCTAssertEqual(staged, formatted(forceNumber - 100))

        calculator.type("7")
        calculator.press(.multiply)
        calculator.clearAll()
        calculator.equals()
        XCTAssertEqual(calculator.display, staged)

        calculator.turnPhoneBack()
        calculator.equals()
        XCTAssertEqual(calculator.display, formatted(forceNumber))
    }

    private func formatted(_ value: Int) -> String {
        CalculatorFormatter.formatResult(Double(value))
    }
}
