import XCTest
@testable import Force

/// Covers the digit-to-pulse decoding, so the count felt in the hand matches the
/// number on screen. The haptic playback itself needs a device and is not tested.
final class PeekHapticsTests: XCTestCase {
    func testEachDigitBecomesItsCount() {
        XCTAssertEqual(
            PeekHaptics.plan(for: "123"),
            [.count(1), .count(2), .count(3)]
        )
    }

    func testZeroIsItsOwnFirmPulse() {
        XCTAssertEqual(PeekHaptics.plan(for: "0"), [.zero])
    }

    /// Grouping commas are visual only and must not add phantom pulses.
    func testGroupingSeparatorsAreIgnored() {
        XCTAssertEqual(
            PeekHaptics.plan(for: "1,204"),
            [.count(1), .count(2), .zero, .count(4)]
        )
    }

    /// The sign and decimal point are not digits, so they are skipped.
    func testSignAndDecimalPointAreSkipped() {
        XCTAssertEqual(
            PeekHaptics.plan(for: "-9.5"),
            [.count(9), .count(5)]
        )
    }

    func testAResultLabelWithNoDigitsProducesNothing() {
        XCTAssertEqual(PeekHaptics.plan(for: "Error"), [])
    }
}
