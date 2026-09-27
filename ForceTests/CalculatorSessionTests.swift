import XCTest
import ForceShared

/// Locks down the behaviour the shared `CalculatorSession` provides on top of
/// `CalculatorOperations`, so a change on one target's calculator cannot silently
/// disagree with the other's.
///
/// Two behaviours in particular used to live on only one side and are the reason
/// this suite exists:
///
/// - AC/C smart clearing, so the top-left key matches the stock iOS calculator.
///   Formerly implemented only in the host `CalculatorView`.
/// - Live peek reporting, so the performer sees what the spectator typed.
///   Formerly implemented only in the clip `CalculatorView`.
///
/// Every test exercises the session both targets now share, so a future refactor
/// that removes one of these breaks the build rather than the trick.
final class CalculatorSessionTests: XCTestCase {
    private let forceNumber = 4_556_325

    // MARK: - AC/C smart clear

    /// With nothing typed, the clear key is AC: it wipes the whole session.
    func testClearActsAsAllClearWhenNothingHasBeenTyped() {
        let (session, _) = makeSession()
        session.calc.forceCount = 2
        session.clear()
        XCTAssertEqual(session.calc.display, "0")
        XCTAssertEqual(session.calc.forceCount, 0, "AC has to zero the count too")
        XCTAssertFalse(session.hasEntryToClear)
    }

    /// After a digit, the key is C: it wipes just the entry and leaves any pending
    /// operator and its left-hand operand alone.
    func testClearActsAsClearEntryAfterADigit() {
        let (session, _) = makeSession()
        session.digitPressed("1")
        session.digitPressed("2")
        session.performOperation(.add)
        session.digitPressed("5")
        XCTAssertEqual(session.calc.display, "5")
        XCTAssertTrue(session.hasEntryToClear)

        session.clear()
        XCTAssertEqual(session.calc.display, "0")
        XCTAssertEqual(session.calc.operation, .add, "the pending sum survives clear-entry")
        XCTAssertEqual(session.calc.previousNumber, 12)
        XCTAssertFalse(session.hasEntryToClear)
    }

    /// A finished calculation is a result, not a half-typed entry, so a following
    /// clear is AC and wipes the count too.
    func testClearAfterEqualsIsAllClearAgain() {
        let (session, _) = makeSession()
        session.digitPressed("2")
        session.performOperation(.add)
        session.digitPressed("3")
        session.equals()
        XCTAssertEqual(session.calc.display, "5")
        XCTAssertFalse(session.hasEntryToClear)

        session.calc.forceCount = 7
        session.clear()
        XCTAssertEqual(session.calc.forceCount, 0)
    }

    /// A pressed operator commits the entry, so the following clear is AC again.
    func testOperatorResetsTheClearMode() {
        let (session, _) = makeSession()
        session.digitPressed("9")
        session.performOperation(.multiply)
        XCTAssertFalse(session.hasEntryToClear)
    }

    /// While the clock sequence is armed, clear is the escape hatch — it cancels
    /// the sequence rather than only wiping the entry, so the performer can always
    /// back out of a setup they no longer want.
    func testClearCancelsAnArmedClockSequence() {
        let (session, _) = makeSession()
        session.toggleQuickEntry()
        session.digitPressed("1")
        session.digitPressed("2")
        XCTAssertEqual(session.quickForce.stage, .awaitingNumber)
        XCTAssertTrue(session.hasEntryToClear)

        session.clear()
        XCTAssertEqual(session.quickForce.stage, .idle)
        XCTAssertEqual(session.calc.display, "0")
    }

    // MARK: - Peek reporting

    /// A digit press schedules a peek report of the current display.
    func testDigitsReportToPeek() {
        let (session, recorder) = makeSession(withPeek: true, debounce: 0.02)
        session.digitPressed("1")
        session.digitPressed("2")
        session.digitPressed("3")
        settle()
        XCTAssertEqual(recorder().map(\.value), ["123"])
        XCTAssertNil(recorder().last?.op, "no operator has closed the entry yet")
    }

    /// An operator closes the entry with the key that ended it, so the performer
    /// sees `123 +` on the peek line rather than a lone `123`.
    func testOperatorClosesThePeekEntry() {
        let (session, recorder) = makeSession(withPeek: true, debounce: 0.02)
        session.digitPressed("1")
        session.digitPressed("2")
        session.digitPressed("3")
        session.performOperation(.add)
        settle()
        XCTAssertEqual(recorder().map(\.op), ["+"])
        XCTAssertEqual(recorder().map(\.value), ["123"])
    }

    /// Equals closes the entry with `=` and follows it with the answer as a new
    /// entry, so the peek line shows `123 =` and then `579`.
    func testEqualsReportsBothTheOperandAndTheAnswer() {
        let (session, recorder) = makeSession(withPeek: true, debounce: 0.02)
        session.digitPressed("1")
        session.digitPressed("2")
        session.digitPressed("3")
        session.performOperation(.add)
        session.digitPressed("4")
        session.digitPressed("5")
        session.digitPressed("6")
        session.equals()
        settle()

        let sent = recorder()
        XCTAssertEqual(sent.map(\.value), ["123", "456", "579"])
        XCTAssertEqual(sent.map(\.op), ["+", "=", nil])
    }

    /// Peek stays quiet while covert force entry is on: the display holds the
    /// performer's setup, not the spectator's number.
    func testPeekIsSuppressedDuringCovertForceEntry() {
        let (session, recorder) = makeSession(withPeek: true, debounce: 0.02)
        session.toggleQuickEntry()
        session.digitPressed("9")
        session.digitPressed("9")
        session.digitPressed("9")
        settle()
        XCTAssertTrue(recorder().isEmpty)
    }

    // MARK: - Perfect Plus lockouts

    /// While the phone is turned away the top-bar controls have to be dead too,
    /// so a spectator's stray press on the readout cannot flip the mode or arm
    /// covert entry.
    func testTopBarControlsAreInertWhilePerfectPlusHoldsTheKeys() {
        let (session, _) = makeSession()
        session.perfectPlusHandler.mode = .armed
        let modeBefore = session.modeName

        session.toggleQuickEntry()
        XCTAssertEqual(session.quickForce.stage, .idle)

        session.toggleMode()
        XCTAssertEqual(session.modeName, modeBefore)

        session.revealMode()
        XCTAssertFalse(session.showModeText)
    }

    // MARK: - Helpers

    /// One delivered peek entry, as the recorder would store it.
    private struct Sent: Equatable {
        let value: String
        let op: String?
    }

    private func makeSession(
        withPeek: Bool = false,
        debounce: TimeInterval = 0.01,
        activationCount: Int = 4
    ) -> (CalculatorSession, () -> [Sent]) {
        let settings = CalculatorSettings()
        settings.forceNumber = forceNumber
        settings.activationCount = activationCount
        settings.magicTrickMode = .forceNumber
        settings.perfectPlusEnabled = false
        settings.livePeekEnabled = withPeek

        final class Box: @unchecked Sendable { var items: [Sent] = [] }
        let box = Box()
        let reporter: PeekReporter? = withPeek
            ? PeekReporter(debounceInterval: debounce) { value, _, op in
                box.items.append(Sent(value: value, op: op))
            }
            : nil

        let session = CalculatorSession(settings: settings, peekReporter: reporter)
        return (session, { box.items })
    }

    private func settle(_ seconds: TimeInterval = 0.1) {
        let done = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 1)
    }
}
