import XCTest
@testable import ForceShared

/// Covers the part of Perfect Plus that decides whether the phone has actually been turned.
///
/// Motion cannot be produced in a test, so these feed the handler the same situations the
/// gravity samples resolve into and check what it does with them. Everything here runs at
/// the sample level, which is where a turn is either recognised or invented.
final class PerfectPlusTurnTests: XCTestCase {
    /// Feeds one situation repeatedly, acting on it whenever the handler says it has settled.
    private func hold(
        _ situation: PerfectPlusHandler.Situation,
        for samples: Int,
        on handler: PerfectPlusHandler
    ) {
        for _ in 0..<samples {
            if let settled = handler.settled(situation) {
                handler.act(on: settled)
            }
        }
    }

    /// A phone on the way over passes through positions it never comes to rest in, so a turn
    /// only counts once it has held still.
    func testATurnHasToHoldBeforeItArms() {
        let handler = PerfectPlusHandler()
        handler.markPendingAdd(operand: 100)

        hold(.turned(.faceDown), for: handler.dwellSamples - 1, on: handler)
        XCTAssertEqual(handler.mode, .pendingAdd, "armed before the turn had settled")

        hold(.turned(.faceDown), for: 1, on: handler)
        XCTAssertEqual(handler.mode, .armed)
    }

    /// The bug this guards: a trick stood down while the phone was face down used to leave a
    /// full count of samples behind, so the next plus armed immediately, with no turn at all.
    func testStandingDownForgetsTheSamplesCountedSoFar() {
        let handler = PerfectPlusHandler()
        handler.markPendingAdd(operand: 100)
        hold(.turned(.faceDown), for: handler.dwellSamples * 4, on: handler)
        XCTAssertEqual(handler.mode, .armed)

        // Equals, clear, or any other operation stands the trick down.
        handler.reset()
        XCTAssertEqual(handler.mode, .inactive)

        // The phone has not moved; it is still lying face down.
        handler.markPendingAdd(operand: 50)
        hold(.turned(.faceDown), for: 1, on: handler)
        XCTAssertEqual(handler.mode, .pendingAdd, "armed off samples counted before the reset")

        hold(.turned(.faceDown), for: handler.dwellSamples - 1, on: handler)
        XCTAssertEqual(handler.mode, .armed, "a real turn should still arm afterwards")
    }

    /// Leaving the calculator and coming back must not carry a count across either.
    func testStoppingMonitoringForgetsTheSamplesCountedSoFar() {
        let handler = PerfectPlusHandler()
        handler.startMonitoring(hapticsEnabled: false) {}
        handler.markPendingAdd(operand: 100)
        hold(.turned(.faceDown), for: handler.dwellSamples * 2, on: handler)
        XCTAssertEqual(handler.mode, .armed)

        handler.stopMonitoring()
        handler.reset()
        handler.startMonitoring(hapticsEnabled: false) {}
        handler.markPendingAdd(operand: 100)

        hold(.turned(.faceDown), for: 1, on: handler)
        XCTAssertEqual(handler.mode, .pendingAdd)
    }

    /// A phone being waved about never rests anywhere, and must not arm on the way.
    func testAlternatingSituationsNeverSettle() {
        let handler = PerfectPlusHandler()
        handler.markPendingAdd(operand: 100)

        for _ in 0..<20 {
            hold(.turned(.faceDown), for: 1, on: handler)
            hold(.between, for: 1, on: handler)
        }
        XCTAssertEqual(handler.mode, .pendingAdd)
    }

    /// With no plus pending the phone can be turned over as much as it likes.
    func testTurningThePhoneWithNoPlusPendingDoesNothing() {
        let handler = PerfectPlusHandler()
        hold(.turned(.faceDown), for: handler.dwellSamples * 3, on: handler)
        XCTAssertEqual(handler.mode, .inactive)
    }

    /// Once the number is staged behind the turn, bringing the phone back is what hands the
    /// keys over, so the performer can press equals.
    func testBringingTheStagedPhoneBackHandsTheKeysOver() {
        var state = CalculatorState()
        let handler = PerfectPlusHandler()
        handler.markPendingAdd(operand: 100)
        hold(.turned(.faceDown), for: handler.dwellSamples, on: handler)

        handler.calculatePerfectAddend(
            state: &state,
            force: ForceValues(number: 4_556_325, activationCount: 3)
        )
        XCTAssertEqual(handler.mode, .staged)
        XCTAssertTrue(handler.mode.keysAreInert)

        hold(.returned, for: handler.dwellSamples, on: handler)
        XCTAssertEqual(handler.mode, .calculated)
        XCTAssertFalse(handler.mode.keysAreInert)
    }
}
