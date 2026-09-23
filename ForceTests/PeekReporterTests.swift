import XCTest
import ForceShared

/// Covers the debounce, gating, and entry grouping that decide what the performer sees
/// of the spectator's calculation. The upload itself is injected, so these run without
/// the network.
final class PeekReporterTests: XCTestCase {
    private let enabled = true
    private let notSuppressed = false

    /// One delivered entry, as the service would store it.
    private struct Sent: Equatable {
        let value: String
        let entryID: String
        let op: String?
    }

    /// A reporter that records what it would have uploaded.
    private func recorder(
        debounce: TimeInterval = 0.01
    ) -> (PeekReporter, () -> [Sent]) {
        final class Box: @unchecked Sendable { var items: [Sent] = [] }
        let box = Box()
        let reporter = PeekReporter(debounceInterval: debounce) { value, entryID, op in
            box.items.append(Sent(value: value, entryID: entryID, op: op))
        }
        return (reporter, { box.items })
    }

    private func settle(_ seconds: TimeInterval = 0.2) {
        let done = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 1)
    }

    // MARK: - Debounce

    func testReportsTheSettledValueAfterTheQuietPeriod() {
        let (reporter, sent) = recorder(debounce: 0.05)
        reporter.report("1,234", enabled: enabled, suppressed: notSuppressed)
        settle()
        XCTAssertEqual(sent().map(\.value), ["1,234"])
    }

    /// Typing a long number is many keystrokes; only the value it settles on should
    /// go out, not one request per digit.
    func testRapidKeystrokesCollapseToOneSend() {
        let (reporter, sent) = recorder(debounce: 0.1)
        for value in ["4", "48", "481", "4815", "48151", "481516"] {
            reporter.report(value, enabled: enabled, suppressed: notSuppressed)
        }
        settle(0.3)
        XCTAssertEqual(sent().map(\.value), ["481516"])
    }

    // MARK: - Gating

    func testNothingIsSentWhenDisabled() {
        let (reporter, sent) = recorder()
        reporter.flush("1,234", enabled: false, suppressed: notSuppressed)
        XCTAssertTrue(sent().isEmpty)
    }

    /// The performer's covert setup must never be broadcast as the spectator's number.
    func testNothingIsSentWhileSuppressed() {
        let (reporter, sent) = recorder()
        reporter.flush("999", enabled: enabled, suppressed: true)
        XCTAssertTrue(sent().isEmpty)
    }

    func testRestingZeroIsNotReported() {
        let (reporter, sent) = recorder()
        reporter.flush("0", enabled: enabled, suppressed: notSuppressed)
        XCTAssertTrue(sent().isEmpty)
    }

    // MARK: - Dedupe and flush

    func testFlushSendsImmediately() {
        let (reporter, sent) = recorder(debounce: 5)
        reporter.flush("42", enabled: enabled, suppressed: notSuppressed)
        XCTAssertEqual(sent().map(\.value), ["42"], "flush must not wait for the debounce")
    }

    func testTheSameValueIsNotSentTwice() {
        let (reporter, sent) = recorder()
        reporter.flush("42", enabled: enabled, suppressed: notSuppressed)
        reporter.flush("42", enabled: enabled, suppressed: notSuppressed)
        XCTAssertEqual(sent().count, 1, "an unchanged display is not worth a second request")
    }

    func testStopCancelsAPendingReport() {
        let (reporter, sent) = recorder(debounce: 0.1)
        reporter.report("77", enabled: enabled, suppressed: notSuppressed)
        reporter.stop()
        settle(0.3)
        XCTAssertTrue(sent().isEmpty, "a report cancelled before it fired must not send")
    }

    // MARK: - The calculation

    /// The point of the transcript: a number and the key that ended it are one entry, so
    /// the performer reads `123 +` rather than seeing `123` twice.
    func testAnOperatorUpdatesTheNumberItEnded() {
        let (reporter, sent) = recorder()
        reporter.flush("123", enabled: enabled, suppressed: notSuppressed)
        reporter.close("123", with: "+", enabled: enabled, suppressed: notSuppressed)

        let items = sent()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].entryID, items[1].entryID, "both belong to the same number")
        XCTAssertNil(items[0].op)
        XCTAssertEqual(items[1].op, "+")
    }

    /// Whatever is typed after an operator is a different number and must not overwrite
    /// the one the performer is already looking at.
    func testTheNextNumberStartsANewEntry() {
        let (reporter, sent) = recorder()
        reporter.flush("123", enabled: enabled, suppressed: notSuppressed)
        reporter.close("123", with: "+", enabled: enabled, suppressed: notSuppressed)
        reporter.flush("456", enabled: enabled, suppressed: notSuppressed)

        let items = sent()
        XCTAssertNotEqual(items.last?.entryID, items.first?.entryID)
        XCTAssertEqual(items.last?.value, "456")
    }

    /// A whole calculation, end to end, as the performer would read it down the screen.
    func testAWholeCalculationReadsInOrder() {
        let (reporter, sent) = recorder()
        reporter.flush("123", enabled: enabled, suppressed: notSuppressed)
        reporter.close("123", with: "+", enabled: enabled, suppressed: notSuppressed)
        reporter.flush("456", enabled: enabled, suppressed: notSuppressed)
        reporter.close("456", with: "=", enabled: enabled, suppressed: notSuppressed)
        reporter.flush("579", enabled: enabled, suppressed: notSuppressed)

        // Collapse the entries the way the service does, keeping the last write per id.
        var byEntry: [String: Sent] = [:]
        var order: [String] = []
        for item in sent() {
            if byEntry[item.entryID] == nil { order.append(item.entryID) }
            byEntry[item.entryID] = item
        }
        let lines = order.compactMap { byEntry[$0] }.map { entry -> String in
            entry.op.map { "\(entry.value) \($0)" } ?? entry.value
        }
        XCTAssertEqual(lines, ["123 +", "456 =", "579"])
    }

    /// Clearing the display finishes nothing, but what comes next is still a new number.
    func testClearStartsANewEntryWithoutReporting() {
        let (reporter, sent) = recorder()
        reporter.flush("123", enabled: enabled, suppressed: notSuppressed)
        let afterFirst = sent().count
        reporter.beginNewEntry()
        reporter.flush("456", enabled: enabled, suppressed: notSuppressed)

        let items = sent()
        XCTAssertEqual(items.count, afterFirst + 1, "clear itself sends nothing")
        XCTAssertNotEqual(items.last?.entryID, items.first?.entryID)
    }
}
