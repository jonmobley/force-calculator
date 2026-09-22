import XCTest
import ForceShared

final class ForceLogicTests: XCTestCase {
    func testForceAppearsOnlyAfterActivationCount() {
        var count = 0
        let first = ForceActivation.advance(calculated: 4, forceCount: count, activationCount: 3, forceValue: 99)
        XCTAssertEqual(first.result, 4)
        XCTAssertEqual(first.forceCount, 1)
        XCTAssertFalse(first.didForce)

        let second = ForceActivation.advance(calculated: 8, forceCount: first.forceCount, activationCount: 3, forceValue: 99)
        XCTAssertEqual(second.result, 8)
        XCTAssertEqual(second.forceCount, 2)

        let third = ForceActivation.advance(calculated: 12, forceCount: second.forceCount, activationCount: 3, forceValue: 99)
        XCTAssertEqual(third.result, 99)
        XCTAssertEqual(third.forceCount, 0)
        XCTAssertTrue(third.didForce)

        let fourth = ForceActivation.advance(calculated: 1, forceCount: third.forceCount, activationCount: 3, forceValue: 99)
        XCTAssertEqual(fourth.result, 1)
        XCTAssertEqual(fourth.forceCount, 1)
        XCTAssertFalse(fourth.didForce)
    }

    func testDateTimeFormatsAtMidnightAndThirteen() {
        let midnight = makeDate(hour: 0, minute: 5)
        XCTAssertEqual(DateTimeNumber.format(midnight.date, format: .mmDDYY, calendar: midnight.calendar), 102_261_205)
        XCTAssertEqual(DateTimeNumber.format(midnight.date, format: .ddMMYY, calendar: midnight.calendar), 201_261_205)
        XCTAssertEqual(DateTimeNumber.format(midnight.date, format: .xxDDMMYY, calendar: midnight.calendar), 1_205_020_126)
        XCTAssertNotEqual(
            DateTimeNumber.format(midnight.date, format: .mmDDYY, calendar: midnight.calendar),
            DateTimeNumber.format(midnight.date, format: .ddMMYY, calendar: midnight.calendar)
        )
        XCTAssertNotEqual(
            DateTimeNumber.format(midnight.date, format: .ddMMYY, calendar: midnight.calendar),
            DateTimeNumber.format(midnight.date, format: .xxDDMMYY, calendar: midnight.calendar)
        )

        let afternoon = makeDate(hour: 13, minute: 5)
        XCTAssertEqual(DateTimeNumber.format(afternoon.date, format: .mmDDYY, calendar: afternoon.calendar), 102_260_105)
        XCTAssertEqual(DateTimeNumber.format(afternoon.date, format: .ddMMYY, calendar: afternoon.calendar), 201_260_105)
        XCTAssertEqual(DateTimeNumber.format(afternoon.date, format: .xxDDMMYY, calendar: afternoon.calendar), 105_020_126)
    }

    func testPlusPerfectAddendAndArming() {
        XCTAssertEqual(PlusPerfectMath.perfectAddend(savedNumber: 100, forceNumber: 4_556_325), 4_556_225)
        XCTAssertTrue(PlusPerfectMath.shouldArm(plusPerfectEnabled: true, isAdd: true, isUpsideDown: true))
        XCTAssertFalse(PlusPerfectMath.shouldArm(plusPerfectEnabled: true, isAdd: true, isUpsideDown: false))
        XCTAssertFalse(PlusPerfectMath.shouldArm(plusPerfectEnabled: false, isAdd: true, isUpsideDown: true))
        XCTAssertFalse(PlusPerfectMath.shouldArm(plusPerfectEnabled: true, isAdd: false, isUpsideDown: true))
    }

    func testAppClipURLRoundTrip() {
        let settings = CalculatorSettings()
        settings.forceNumber = 77
        settings.activationCount = 4
        settings.magicTrickMode = .exactDateTime
        settings.dateTimeFormat = .xxDDMMYY
        settings.buttonTheme = .pink
        settings.plusPerfectEnabled = true
        settings.startWithScreenshot = true

        let url = AppClipQuery(settings: settings).url()
        XCTAssertTrue(url.absoluteString.hasPrefix("https://appclip.apple.com/id"))
        XCTAssertEqual(AppClipQuery.bundleIdentifier(in: url), AppClipQuery.clipBundleIdentifier)

        let fresh = CalculatorSettings()
        AppClipQuery.apply(url, to: fresh)
        XCTAssertEqual(fresh.forceNumber, 77)
        XCTAssertEqual(fresh.activationCount, 4)
        XCTAssertEqual(fresh.magicTrickMode, .exactDateTime)
        XCTAssertEqual(fresh.dateTimeFormat, .xxDDMMYY)
        XCTAssertEqual(fresh.buttonTheme, .pink)
        XCTAssertTrue(fresh.plusPerfectEnabled)
        XCTAssertTrue(fresh.startWithScreenshot)
        XCTAssertEqual(settings.forceNumber, 77)
    }

    func testSettingsJSONRoundTripKeepsLaunchFlags() {
        let settings = CalculatorSettings()
        settings.forceNumber = 42
        settings.plusPerfectEnabled = true
        settings.startWithScreenshot = true
        settings.dateTimeFormat = .ddMMYY

        let data = try? JSONEncoder().encode(settings)
        guard let data, let decoded = try? JSONDecoder().decode(CalculatorSettings.self, from: data) else {
            XCTFail("Settings JSON did not round-trip")
            return
        }
        XCTAssertEqual(decoded.forceNumber, 42)
        XCTAssertTrue(decoded.plusPerfectEnabled)
        XCTAssertTrue(decoded.startWithScreenshot)
        XCTAssertEqual(decoded.dateTimeFormat, .ddMMYY)

        let live = CalculatorSettings()
        live.applyStored(decoded)
        XCTAssertTrue(live.startWithScreenshot)
        XCTAssertTrue(live.plusPerfectEnabled)
    }

    private func makeDate(hour: Int, minute: Int) -> (date: Date, calendar: Calendar) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var parts = DateComponents()
        parts.calendar = calendar
        parts.timeZone = calendar.timeZone
        parts.year = 2026
        parts.month = 1
        parts.day = 2
        parts.hour = hour
        parts.minute = minute
        return (calendar.date(from: parts)!, calendar)
    }
}
