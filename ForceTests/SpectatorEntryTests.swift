import XCTest
import ForceShared
@testable import Force

/// The earpiece voice hears about the numbers the spectator finishes, and never
/// about the performer's own covert setup.
final class SpectatorEntryTests: XCTestCase {
    func testOperatorAndEqualsReportTheTypedNumbersAndTheAnswer() {
        let (session, entries) = makeSession()
        session.digitPressed("1")
        session.digitPressed("2")
        session.performOperation(.add)
        session.digitPressed("3")
        session.equals()
        XCTAssertEqual(entries(), [.typed("12"), .typed("3"), .answer("15")])
    }

    func testAnOperatorWithNothingTypedReportsNothing() {
        let (session, entries) = makeSession()
        session.digitPressed("5")
        session.performOperation(.add)
        session.performOperation(.subtract)
        XCTAssertEqual(entries(), [.typed("5")])
    }

    func testCovertForceEntryIsNeverReported() {
        let (session, entries) = makeSession()
        session.toggleQuickEntry()
        session.digitPressed("9")
        session.digitPressed("9")
        session.equals()
        XCTAssertEqual(entries(), [])
    }

    func testDigitsAreReadOneAtATime() {
        XCTAssertEqual(EarpieceVoice.digits("4,521"), "4, 5, 2, 1")
        XCTAssertEqual(EarpieceVoice.digits("-12.5"), "minus, 1, 2, point, 5")
        XCTAssertEqual(EarpieceVoice.digits("0"), "0")
    }

    private func makeSession() -> (CalculatorSession, () -> [SpectatorEntry]) {
        let settings = CalculatorSettings()
        settings.forceNumber = 4_556_325
        settings.activationCount = 4
        settings.magicTrickMode = .forceNumber
        settings.perfectPlusEnabled = false
        let session = CalculatorSession(settings: settings)
        final class Box { var items: [SpectatorEntry] = [] }
        let box = Box()
        session.onSpectatorEntry = { box.items.append($0) }
        return (session, { box.items })
    }
}
