import XCTest
import ForceShared

/// Covers the debounce and gating that decide when the spectator's number is
/// reported. The upload itself is injected, so these run without the network.
final class PeekReporterTests: XCTestCase {
    private let enabled = true
    private let notSuppressed = false

    // MARK: - Debounce

    func testReportsTheSettledValueAfterTheQuietPeriod() {
        var sent: [String] = []
        let reporter = PeekReporter(debounceInterval: 0.05) { sent.append($0) }
        let done = expectation(description: "sent")

        reporter.report("1,234", enabled: enabled, suppressed: notSuppressed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { done.fulfill() }

        wait(for: [done], timeout: 1)
        XCTAssertEqual(sent, ["1,234"])
    }

    /// Typing a long number is many keystrokes; only the value it settles on should
    /// go out, not one request per digit.
    func testRapidKeystrokesCollapseToOneSend() {
        var sent: [String] = []
        let reporter = PeekReporter(debounceInterval: 0.1) { sent.append($0) }
        let done = expectation(description: "sent")

        for value in ["4", "48", "481", "4815", "48151", "481516"] {
            reporter.report(value, enabled: enabled, suppressed: notSuppressed)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { done.fulfill() }

        wait(for: [done], timeout: 1)
        XCTAssertEqual(sent, ["481516"])
    }

    // MARK: - Gating

    func testNothingIsSentWhenDisabled() {
        var sent: [String] = []
        let reporter = PeekReporter(debounceInterval: 0.01) { sent.append($0) }

        reporter.flush("1,234", enabled: false, suppressed: notSuppressed)

        XCTAssertTrue(sent.isEmpty)
    }

    /// The performer's covert setup must never be broadcast as the spectator's number.
    func testNothingIsSentWhileSuppressed() {
        var sent: [String] = []
        let reporter = PeekReporter(debounceInterval: 0.01) { sent.append($0) }

        reporter.flush("999", enabled: enabled, suppressed: true)

        XCTAssertTrue(sent.isEmpty)
    }

    func testRestingZeroIsNotReported() {
        var sent: [String] = []
        let reporter = PeekReporter(debounceInterval: 0.01) { sent.append($0) }

        reporter.flush("0", enabled: enabled, suppressed: notSuppressed)

        XCTAssertTrue(sent.isEmpty)
    }

    // MARK: - Dedupe and flush

    func testFlushSendsImmediately() {
        var sent: [String] = []
        let reporter = PeekReporter(debounceInterval: 5) { sent.append($0) }

        reporter.flush("42", enabled: enabled, suppressed: notSuppressed)

        XCTAssertEqual(sent, ["42"], "flush must not wait for the debounce")
    }

    func testTheSameValueIsNotSentTwice() {
        var sent: [String] = []
        let reporter = PeekReporter(debounceInterval: 0.01) { sent.append($0) }

        reporter.flush("42", enabled: enabled, suppressed: notSuppressed)
        reporter.flush("42", enabled: enabled, suppressed: notSuppressed)

        XCTAssertEqual(sent, ["42"], "an unchanged display is not worth a second request")
    }

    func testStopCancelsAPendingReport() {
        var sent: [String] = []
        let reporter = PeekReporter(debounceInterval: 0.1) { sent.append($0) }
        let done = expectation(description: "waited")

        reporter.report("77", enabled: enabled, suppressed: notSuppressed)
        reporter.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { done.fulfill() }

        wait(for: [done], timeout: 1)
        XCTAssertTrue(sent.isEmpty, "a report cancelled before it fired must not send")
    }
}
