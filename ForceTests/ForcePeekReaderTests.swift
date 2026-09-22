import XCTest
import ForceShared
@testable import Force

/// Covers the age rule that keeps a previous spectator's number from lingering on
/// the readout. The network fetch itself is not exercised here.
@MainActor
final class ForcePeekReaderTests: XCTestCase {
    private let value = "1,234"

    func testAFreshPeekIsShown() {
        let peek = ForcePeekService.Peek(value: value, updatedAt: Date())
        XCTAssertEqual(ForcePeekReader.freshValue(peek), peek)
    }

    func testAStalePeekIsIgnored() {
        let now = Date()
        let old = now.addingTimeInterval(-(ForcePeekReader.staleAfter + 1))
        let peek = ForcePeekService.Peek(value: value, updatedAt: old)

        XCTAssertNil(ForcePeekReader.freshValue(peek, now: now))
    }

    func testAPeekRightAtTheEdgeIsStillShown() {
        let now = Date()
        let edge = now.addingTimeInterval(-ForcePeekReader.staleAfter)
        let peek = ForcePeekService.Peek(value: value, updatedAt: edge)

        XCTAssertEqual(ForcePeekReader.freshValue(peek, now: now), peek)
    }

    /// A service clock a little ahead of the device reads as a negative age, which
    /// is skew rather than staleness and must not hide the value.
    func testClockSkewFromTheFutureIsNotTreatedAsStale() {
        let now = Date()
        let future = now.addingTimeInterval(5)
        let peek = ForcePeekService.Peek(value: value, updatedAt: future)

        XCTAssertEqual(ForcePeekReader.freshValue(peek, now: now), peek)
    }

    func testNoPeekStaysNil() {
        XCTAssertNil(ForcePeekReader.freshValue(nil))
    }
}
