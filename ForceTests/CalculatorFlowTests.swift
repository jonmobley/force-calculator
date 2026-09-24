import XCTest
import ForceShared

/// Ordinary arithmetic pressed through the shared key handling. The calculator has to be
/// convincing before it can be clever: a spectator who chains operators the way they would
/// on the stock calculator has to get the stock calculator's answers.
final class CalculatorFlowTests: XCTestCase {
    private let forceNumber = 4_556_325

    /// An operator pressed part-way through an entry finishes the sum already under way, so
    /// the display carries the running total rather than the operand just typed.
    func testChainedOperatorCarriesTheRunningTotal() {
        let calculator = TestCalculator(forceNumber: forceNumber, activationCount: 4)
        calculator.type("2")
        calculator.press(.add)
        calculator.type("3")
        calculator.press(.add)
        XCTAssertEqual(calculator.display, "5")

        calculator.type("4")
        calculator.equals()
        XCTAssertEqual(calculator.display, "9")
    }

    /// Chained sums run left to right with no precedence, the same as the stock calculator.
    func testChainedOperatorsRunLeftToRight() {
        let calculator = TestCalculator(forceNumber: forceNumber, activationCount: 4)
        calculator.type("2")
        calculator.press(.add)
        calculator.type("3")
        calculator.press(.multiply)
        XCTAssertEqual(calculator.display, "5")

        calculator.type("4")
        calculator.equals()
        XCTAssertEqual(calculator.display, "20")
    }

    /// The sum a chained operator finishes is one the spectator watched land, so it counts
    /// toward the activation count like any other completed calculation.
    func testChainedOperatorCountsTowardTheForce() {
        let calculator = TestCalculator(
            forceNumber: forceNumber,
            activationCount: 2,
            perfectPlusEnabled: false
        )
        calculator.type("2")
        calculator.press(.add)
        calculator.type("3")
        calculator.press(.add)
        XCTAssertEqual(calculator.display, "5", "the chained press is the first of the two")

        calculator.type("4")
        calculator.equals()
        XCTAssertEqual(
            calculator.display,
            CalculatorFormatter.formatResult(Double(forceNumber)),
            "the second press lands on the force"
        )
    }

    /// An operator pressed on a result rather than part-way through an entry has no sum to
    /// finish, so it must not spend a press of the count.
    func testOperatorOnAResultFinishesNothing() {
        let calculator = TestCalculator(forceNumber: forceNumber, activationCount: 4)
        calculator.type("2")
        calculator.press(.add)
        calculator.type("2")
        calculator.equals()
        XCTAssertEqual(calculator.display, "4")

        calculator.press(.multiply)
        calculator.type("3")
        calculator.equals()
        XCTAssertEqual(calculator.display, "12")
    }

    /// A second equals repeats the last operation. Stock calculators do `12 + 34 =`
    /// then `=` to get 80, not 92.
    func testRepeatEqualsReappliesTheLastOperand() {
        let calculator = TestCalculator(
            forceNumber: forceNumber,
            activationCount: 4,
            perfectPlusEnabled: false
        )
        calculator.type("12")
        calculator.press(.add)
        calculator.type("34")
        calculator.equals()
        XCTAssertEqual(calculator.display, "46")

        calculator.equals()
        XCTAssertEqual(calculator.display, "80")

        calculator.equals()
        XCTAssertEqual(calculator.display, "114")
    }

    /// Once the force has landed, another equals has to leave it there. Repeating
    /// the last sum would walk the display off the number the spectator just saw.
    func testEqualsAfterTheForceLeavesTheNumberInPlace() {
        let calculator = TestCalculator(
            forceNumber: forceNumber,
            activationCount: 3,
            perfectPlusEnabled: false
        )
        calculator.type("12")
        calculator.press(.add)
        calculator.type("34")
        calculator.equals()
        calculator.equals()
        calculator.equals()
        XCTAssertEqual(calculator.display, CalculatorFormatter.formatResult(Double(forceNumber)))

        calculator.equals()
        XCTAssertEqual(calculator.display, CalculatorFormatter.formatResult(Double(forceNumber)))
    }

    /// `200 + 10 %` is 10 percent of 200, and equals finishes the sum.
    func testPercentOfAnAdditionFinishesOnEquals() {
        let calculator = TestCalculator(
            forceNumber: forceNumber,
            activationCount: 4,
            perfectPlusEnabled: false
        )
        calculator.type("200")
        calculator.press(.add)
        calculator.type("10")
        calculator.press(.percent)
        XCTAssertEqual(calculator.display, "20")

        calculator.equals()
        XCTAssertEqual(calculator.display, "220")
    }

    /// Multiply and divide take the typed number over 100, so `200 × 50 %` is 100.
    func testPercentScalesAProduct() {
        let calculator = TestCalculator(
            forceNumber: forceNumber,
            activationCount: 4,
            perfectPlusEnabled: false
        )
        calculator.type("200")
        calculator.press(.multiply)
        calculator.type("50")
        calculator.press(.percent)
        calculator.equals()
        XCTAssertEqual(calculator.display, "100")
    }

    /// With nothing pending, percent divides the display by 100.
    func testPercentAloneDividesByOneHundred() {
        let calculator = TestCalculator(
            forceNumber: forceNumber,
            activationCount: 4,
            perfectPlusEnabled: false
        )
        calculator.type("50")
        calculator.press(.percent)
        XCTAssertEqual(calculator.display, "0.5")

        calculator.equals()
        XCTAssertEqual(calculator.display, "0.5")
    }

    /// A digit after percent replaces that operand. An operator finishes the sum first.
    func testPercentChainsAndANewDigitReplacesIt() {
        let calculator = TestCalculator(
            forceNumber: forceNumber,
            activationCount: 4,
            perfectPlusEnabled: false
        )
        calculator.type("200")
        calculator.press(.add)
        calculator.type("10")
        calculator.press(.percent)
        calculator.type("5")
        XCTAssertEqual(calculator.display, "5")
        calculator.equals()
        XCTAssertEqual(calculator.display, "205")

        calculator.type("200")
        calculator.press(.add)
        calculator.type("10")
        calculator.press(.percent)
        calculator.press(.add)
        XCTAssertEqual(calculator.display, "220")
        calculator.type("5")
        calculator.equals()
        XCTAssertEqual(calculator.display, "225")
    }

    func testOnlyAHalfFinishedEntryCountsAsAPendingSum() {
        XCTAssertTrue(CalculatorOperations.shouldFinishPendingSum(
            state(operation: .add, userIsTyping: true),
            perfectPlusMode: .inactive
        ))
        // The keypad is inert while armed, so there is nothing to finish.
        XCTAssertFalse(CalculatorOperations.shouldFinishPendingSum(
            state(operation: .add, userIsTyping: true),
            perfectPlusMode: .armed
        ))
        XCTAssertFalse(CalculatorOperations.shouldFinishPendingSum(
            state(operation: nil, userIsTyping: true),
            perfectPlusMode: .inactive
        ))
        // A result sitting on the display is not a half-finished entry.
        XCTAssertFalse(CalculatorOperations.shouldFinishPendingSum(
            state(operation: .add, userIsTyping: false),
            perfectPlusMode: .inactive
        ))
    }

    private func state(
        operation: CalculatorOperation?,
        userIsTyping: Bool
    ) -> CalculatorState {
        var state = CalculatorState()
        state.operation = operation
        state.userIsTyping = userIsTyping
        return state
    }
}
