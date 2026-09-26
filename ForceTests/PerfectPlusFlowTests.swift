import XCTest
import ForceShared

/// Covers what the keypad does once a Perfect Plus reveal has landed. The tests in
/// `ForceLogicTests` check the decisions that lead up to the reveal; these press real keys
/// afterwards, because the state the reveal leaves behind is what the spectator gets to
/// play with.
final class PerfectPlusFlowTests: XCTestCase {
    private let forceNumber = 4_556_325

    /// The equals-press count is the other reveal, so it stays quiet while Perfect Plus
    /// is the one in use. An immediate force would otherwise replace this sum.
    func testOrdinarySumsStayHonestWhilePerfectPlusIsOn() {
        let calculator = TestCalculator(
            forceNumber: forceNumber,
            activationCount: 1,
            perfectPlusEnabled: true
        )
        calculator.type("2")
        calculator.press(.add)
        calculator.type("3")
        calculator.equals()
        XCTAssertEqual(calculator.display, "5")
    }

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

    /// Both calculators draw `expressionDisplay`, so the number has to reach it, not just
    /// `display`. Without it the readout sat on `100+` while the phone came back.
    func testStagedNumberShowsInTheReadout() {
        let calculator = TestCalculator(forceNumber: forceNumber, activationCount: 3)
        calculator.stageTheNumberBehindTheTurn(savedNumber: 100)
        XCTAssertEqual(calculator.expressionDisplay, "100+\(formatted(forceNumber - 100))")

        calculator.turnPhoneBack()
        XCTAssertEqual(calculator.expressionDisplay, "100+\(formatted(forceNumber - 100))")
        calculator.equals()
        XCTAssertEqual(calculator.expressionDisplay, formatted(forceNumber))
    }

    /// An operator after the number finishes the sum first, as it would on any calculator,
    /// rather than dropping the number the plus was pressed on.
    func testOperatorAfterTheNumberFinishesTheSum() {
        let calculator = TestCalculator(forceNumber: forceNumber, activationCount: 3)
        calculator.type("100")
        calculator.press(.add)
        calculator.turnPhoneOverAndBack()
        calculator.press(.multiply)
        XCTAssertEqual(calculator.expressionDisplay, "\(formatted(forceNumber))×")
    }

    private func formatted(_ value: Int) -> String {
        CalculatorFormatter.formatResult(Double(value))
    }
}
