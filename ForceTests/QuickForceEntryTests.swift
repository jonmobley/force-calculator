import XCTest
import ForceShared

/// Covers the clock-button sequence: tap the clock, type a number, press equals, press one
/// digit for the count. The sequence has to be forgiving about slips, because it is run in
/// company and a wrong turn cannot be inspected at the time.
final class QuickForceEntryTests: XCTestCase {
    private let savedForce = 4_556_325
    private let savedActivation = 3

    // MARK: - The sequence

    func testSequenceOverridesBothValues() {
        let entry = QuickForceEntry()
        let settings = savedSettings()

        XCTAssertEqual(entry.values(settings: settings).number, savedForce)

        entry.toggle()
        XCTAssertEqual(entry.stage, .awaitingNumber)

        XCTAssertTrue(entry.consumeEquals(display: "1,234"))
        XCTAssertEqual(entry.stage, .awaitingActivation)
        // Nothing is in force until the count lands.
        XCTAssertEqual(entry.values(settings: settings).number, savedForce)

        XCTAssertTrue(entry.consumeDigit("2"))
        XCTAssertEqual(entry.stage, .idle)
        XCTAssertEqual(
            entry.values(settings: settings),
            ForceValues(number: 1234, activationCount: 2)
        )
    }

    /// Digits belong to the display while the number is being typed; only the digit that
    /// sets the count is taken away from it.
    func testOnlyTheCountDigitIsConsumed() {
        let entry = QuickForceEntry()
        entry.toggle()

        XCTAssertFalse(entry.consumeDigit("7"))
        XCTAssertFalse(entry.consumeDigit("7"))

        _ = entry.consumeEquals(display: "77")
        XCTAssertTrue(entry.consumeDigit("4"))
    }

    func testKeysAreUntouchedWhenIdle() {
        let entry = QuickForceEntry()
        XCTAssertFalse(entry.consumeEquals(display: "12"))
        XCTAssertFalse(entry.consumeDigit("1"))
    }

    // MARK: - Slips

    /// Equals pressed before anything was typed must not commit a force of nothing, and the
    /// clock has to stay armed so the performer can simply type it again.
    func testEqualsOnAnEmptyDisplayStaysArmed() {
        let entry = QuickForceEntry()
        entry.toggle()

        XCTAssertTrue(entry.consumeEquals(display: "0"))
        XCTAssertEqual(entry.stage, .awaitingNumber)

        XCTAssertTrue(entry.consumeEquals(display: "50"))
        XCTAssertEqual(entry.stage, .awaitingActivation)
    }

    func testResultTooWideToForceIsRefused() {
        let entry = QuickForceEntry()
        entry.toggle()

        XCTAssertTrue(entry.consumeEquals(display: "1e+20"))
        XCTAssertEqual(entry.stage, .awaitingNumber)
        XCTAssertNil(entry.override)
    }

    /// Zero cannot be a number of presses, so it leaves the sequence waiting rather than
    /// committing something the performer cannot have meant.
    func testZeroIsNotAnActivationCount() {
        let entry = QuickForceEntry()
        entry.toggle()
        _ = entry.consumeEquals(display: "99")

        XCTAssertTrue(entry.consumeDigit("0"))
        XCTAssertEqual(entry.stage, .awaitingActivation)
        XCTAssertNil(entry.override)

        XCTAssertTrue(entry.consumeDigit("5"))
        XCTAssertEqual(entry.override, ForceValues(number: 99, activationCount: 5))
    }

    /// A second equals while the count is still owed would otherwise run the calculation the
    /// display only looks like it is holding.
    func testSecondEqualsIsSwallowedWhileCountIsOwed() {
        let entry = QuickForceEntry()
        entry.toggle()
        _ = entry.consumeEquals(display: "99")

        XCTAssertTrue(entry.consumeEquals(display: "99"))
        XCTAssertEqual(entry.stage, .awaitingActivation)
    }

    // MARK: - Backing out

    func testTappingTheClockAgainAbandonsTheSequence() {
        let entry = QuickForceEntry()
        let settings = savedSettings()
        entry.toggle()
        _ = entry.consumeEquals(display: "99")

        XCTAssertEqual(entry.toggle(), .idle)
        XCTAssertNil(entry.override)

        // The abandoned number must not resurface: the next sequence commits its own.
        punchIn(entry, number: "12", count: "2")
        XCTAssertEqual(
            entry.values(settings: settings),
            ForceValues(number: 12, activationCount: 2)
        )
    }

    /// Clear backs out of an armed clock, but an override already set has to survive it:
    /// the spectator is handed the phone and is free to press clear.
    func testCancelKeepsACommittedOverride() {
        let entry = QuickForceEntry()
        let settings = savedSettings()
        punchIn(entry, number: "1,234", count: "2")

        entry.cancel()
        XCTAssertEqual(entry.values(settings: settings).number, 1234)
    }

    func testResetHandsTheTrickBackToTheSavedSettings() {
        let entry = QuickForceEntry()
        let settings = savedSettings()
        punchIn(entry, number: "1,234", count: "2")

        entry.reset()
        XCTAssertEqual(
            entry.values(settings: settings),
            ForceValues(number: savedForce, activationCount: savedActivation)
        )
    }

    // MARK: - Resolving

    /// A number typed in by hand is an explicit instruction, so it has to beat the clock
    /// rather than be quietly ignored in Date and Time mode.
    func testOverrideBeatsDateAndTimeMode() {
        let entry = QuickForceEntry()
        let settings = savedSettings()
        settings.magicTrickMode = .exactDateTime
        punchIn(entry, number: "1,234", count: "1")

        XCTAssertEqual(entry.values(settings: settings).number, 1234)
        XCTAssertEqual(entry.modeName(settings: settings), QuickForceEntry.overrideName)
    }

    func testModeNameFallsBackToTheSavedMode() {
        let entry = QuickForceEntry()
        let settings = savedSettings()
        XCTAssertEqual(entry.modeName(settings: settings), MagicTrickMode.forceNumber.rawValue)
    }

    // MARK: - Helpers

    /// Runs the whole sequence, which most of these tests need only as a starting point.
    private func punchIn(_ entry: QuickForceEntry, number: String, count: String) {
        entry.toggle()
        _ = entry.consumeEquals(display: number)
        _ = entry.consumeDigit(count)
    }

    private func savedSettings() -> CalculatorSettings {
        let settings = CalculatorSettings()
        settings.forceNumber = savedForce
        settings.activationCount = savedActivation
        settings.magicTrickMode = .forceNumber
        return settings
    }
}

/// The same sequence pressed through the shared key handling, which is what proves the
/// override reaches the equals key and that nothing is left on the display afterwards.
final class QuickForceEntryFlowTests: XCTestCase {
    func testClockSequenceChangesWhatEqualsForces() {
        let calculator = TestCalculator(forceNumber: 4_556_325, activationCount: 3)

        calculator.tapClock()
        calculator.type("1234")
        XCTAssertEqual(calculator.display, "1,234", "the number types into the display as normal")
        calculator.equals()
        calculator.type("2")

        XCTAssertEqual(calculator.quickEntryStage, .idle, "the clock returns to normal")
        XCTAssertEqual(calculator.display, "0", "and leaves nothing behind")
        XCTAssertEqual(calculator.force, ForceValues(number: 1234, activationCount: 2))

        // Two presses now, rather than the three the saved settings asked for.
        calculator.type("2")
        calculator.press(.add)
        calculator.type("2")
        calculator.equals()
        XCTAssertEqual(calculator.display, "4", "the first press is an honest sum")

        calculator.equals()
        XCTAssertEqual(calculator.display, "1,234", "the second lands on the new number")
    }

    /// Equals must not calculate while the sequence is running, or the number the performer
    /// typed would be replaced by a result before it could be captured.
    func testEqualsDoesNotCalculateMidSequence() {
        let calculator = TestCalculator(forceNumber: 999, activationCount: 1)

        calculator.tapClock()
        calculator.type("50")
        calculator.press(.add)
        calculator.type("50")
        calculator.equals()
        XCTAssertEqual(calculator.display, "50", "no sum ran, so the typed number stands")

        calculator.type("1")
        XCTAssertEqual(calculator.force, ForceValues(number: 50, activationCount: 1))
    }

    func testClearBacksOutOfAnArmedClock() {
        let calculator = TestCalculator(forceNumber: 777, activationCount: 2)

        calculator.tapClock()
        calculator.type("1234")
        calculator.clearAll()
        XCTAssertEqual(calculator.quickEntryStage, .idle)

        // Keys go back to the calculator, and the saved force is still the one in play.
        calculator.type("8")
        XCTAssertEqual(calculator.display, "8")
        XCTAssertEqual(calculator.force, ForceValues(number: 777, activationCount: 2))
    }

    func testOverrideEndsWithTheSession() {
        let calculator = TestCalculator(forceNumber: 4_556_325, activationCount: 3)

        calculator.tapClock()
        calculator.type("11")
        calculator.equals()
        calculator.type("1")
        XCTAssertEqual(calculator.force.number, 11)

        calculator.close()
        XCTAssertEqual(calculator.force, ForceValues(number: 4_556_325, activationCount: 3))
    }

    /// Perfect Plus reaches for the same pair of numbers, so a quick-set force has to move
    /// the addend with it.
    func testPerfectPlusUsesTheOverride() {
        let calculator = TestCalculator(forceNumber: 4_556_325, activationCount: 3)

        calculator.tapClock()
        calculator.type("500")
        calculator.equals()
        calculator.type("1")

        calculator.type("200")
        calculator.press(.add)
        calculator.turnPhoneOverAndBack()
        XCTAssertEqual(calculator.display, "300", "the addend reaches the overridden force")

        calculator.equals()
        XCTAssertEqual(calculator.display, "500")
    }
}
