import XCTest
import ForceShared
@testable import Force

/// Covers the age rule that keeps a previous spectator's calculation from lingering on
/// the readout, and how a calculation reads once it has entries. The network fetch
/// itself is not exercised here.
@MainActor
final class ForcePeekReaderTests: XCTestCase {
    private func peek(at date: Date, value: String = "1,234") -> ForcePeekService.Peek {
        ForcePeekService.Peek(entries: [
            ForcePeekService.Entry(id: "1", value: value, at: date)
        ])
    }

    func testAFreshPeekIsShown() {
        let fresh = peek(at: Date())
        XCTAssertEqual(ForcePeekReader.freshValue(fresh), fresh)
    }

    func testAStalePeekIsIgnored() {
        let now = Date()
        let old = peek(at: now.addingTimeInterval(-(ForcePeekReader.staleAfter + 1)))

        XCTAssertNil(ForcePeekReader.freshValue(old, now: now))
    }

    func testAPeekRightAtTheEdgeIsStillShown() {
        let now = Date()
        let edge = peek(at: now.addingTimeInterval(-ForcePeekReader.staleAfter))

        XCTAssertEqual(ForcePeekReader.freshValue(edge, now: now), edge)
    }

    /// A service clock a little ahead of the device reads as a negative age, which
    /// is skew rather than staleness and must not hide the value.
    func testClockSkewFromTheFutureIsNotTreatedAsStale() {
        let now = Date()
        let future = peek(at: now.addingTimeInterval(5))

        XCTAssertEqual(ForcePeekReader.freshValue(future, now: now), future)
    }

    func testNoPeekStaysNil() {
        XCTAssertNil(ForcePeekReader.freshValue(nil))
    }

    /// Age is judged on the newest entry. An older step in the same calculation must not
    /// drag a calculation the spectator is still working on off the readout.
    func testAgeFollowsTheNewestEntry() {
        let now = Date()
        let calculation = ForcePeekService.Peek(entries: [
            ForcePeekService.Entry(
                id: "1", value: "123", op: "+",
                at: now.addingTimeInterval(-(ForcePeekReader.staleAfter + 30))
            ),
            ForcePeekService.Entry(id: "2", value: "456", at: now)
        ])

        XCTAssertEqual(ForcePeekReader.freshValue(calculation, now: now), calculation)
    }

    /// The transcript is what the performer reads, so each line has to say the number
    /// and the key that ended it.
    func testEntryReadsAsTheNumberThenTheKey() {
        XCTAssertEqual(
            ForcePeekService.Entry(id: "1", value: "123", op: "+", at: Date()).line,
            "123 +"
        )
        XCTAssertEqual(
            ForcePeekService.Entry(id: "2", value: "579", at: Date()).line,
            "579"
        )
    }

    /// Show Big and the haptics both speak for whatever is on the spectator's screen
    /// now, which is the last thing reported.
    func testLatestIsTheEndOfTheCalculation() {
        let calculation = ForcePeekService.Peek(entries: [
            ForcePeekService.Entry(id: "1", value: "123", op: "+", at: Date()),
            ForcePeekService.Entry(id: "2", value: "456", op: "=", at: Date()),
            ForcePeekService.Entry(id: "3", value: "579", at: Date())
        ])

        XCTAssertEqual(calculation.latest?.value, "579")
    }

    /// A live calculation keeps the fast cadence so the performer sees each digit.
    func testActivePollIntervalWhileShowingAValue() {
        let calculation = peek(at: Date())
        XCTAssertEqual(
            ForcePeekReader.pollInterval(for: .value(calculation)),
            ForcePeekReader.activePollInterval
        )
    }

    /// Silence stretches the gap so a phone left open with peek on does not burn
    /// two requests a second all afternoon.
    func testWaitingPollIntervalWhileQuiet() {
        XCTAssertEqual(
            ForcePeekReader.pollInterval(for: .waiting),
            ForcePeekReader.waitingPollInterval
        )
    }
}
