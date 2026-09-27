import XCTest
import ForceShared

/// Special Day mode: a date and time preset by the performer, revealed in the same
/// digit layout as Date and Time mode.
final class SpecialDayTests: XCTestCase {
    private let christmasEvening = SpecialDay(year: 2026, month: 12, day: 25, hour: 19, minute: 30)

    // MARK: - Formatting

    func testSpecialDayFollowsEachDateTimeFormat() {
        XCTAssertEqual(DateTimeNumber.format(christmasEvening, format: .mmDDYY), 1_225_260_730)
        XCTAssertEqual(DateTimeNumber.format(christmasEvening, format: .ddMMYY), 2_512_260_730)
        XCTAssertEqual(DateTimeNumber.format(christmasEvening, format: .xxDDMMYY), 730_251_226)
    }

    func testMidnightAndNoonReadAsTwelve() {
        let midnight = SpecialDay(year: 2027, month: 1, day: 1, hour: 0, minute: 0)
        let noon = SpecialDay(year: 2027, month: 1, day: 1, hour: 12, minute: 5)
        XCTAssertEqual(DateTimeNumber.format(midnight, format: .xxDDMMYY), 1_200_010_127)
        XCTAssertEqual(DateTimeNumber.format(noon, format: .xxDDMMYY), 1_205_010_127)
    }

    /// The spectator's phone may be in another time zone, so the day has to reveal the
    /// wall-clock moment the performer chose rather than shift with the clock.
    func testSpecialDayRoundTripsThroughAnyTimeZone() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = christmasEvening.date(calendar: tokyo)
        XCTAssertEqual(SpecialDay(date: date, calendar: tokyo), christmasEvening)
    }

    func testNextOccurrenceNeverLandsInThePast() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27))!

        XCTAssertEqual(SpecialDay.next(month: 10, day: 31, now: now, calendar: calendar).year, 2026)
        XCTAssertEqual(SpecialDay.next(month: 9, day: 27, now: now, calendar: calendar).year, 2026)
        XCTAssertEqual(SpecialDay.next(month: 1, day: 1, now: now, calendar: calendar).year, 2027)
    }

    // MARK: - Settings

    func testForcedNumberUsesSpecialDayInSpecialDayMode() {
        let settings = CalculatorSettings()
        settings.forceNumber = 42
        settings.specialDay = christmasEvening
        settings.dateTimeFormat = .ddMMYY

        settings.magicTrickMode = .specialDay
        XCTAssertEqual(settings.forcedNumber, 2_512_260_730)

        settings.magicTrickMode = .forceNumber
        XCTAssertEqual(settings.forcedNumber, 42)
    }

    func testSpecialDaySurvivesThePublishedPayload() throws {
        let settings = CalculatorSettings()
        settings.magicTrickMode = .specialDay
        settings.specialDay = christmasEvening

        let payload = try JSONEncoder().encode(settings.snapshot())
        let decoded = try JSONDecoder().decode(CalculatorSettings.self, from: payload)

        XCTAssertEqual(decoded.magicTrickMode, .specialDay)
        XCTAssertEqual(decoded.specialDay, christmasEvening)
    }

    func testRecordWithoutSpecialDayStillDecodes() throws {
        let legacy = Data(#"{"theme":"dark","forceNumber":1,"activationCount":3,"#.utf8)
            + Data(#""currentCount":0,"magicTrickMode":"Date and Time"}"#.utf8)
        let old = try JSONDecoder().decode(CalculatorSettings.self, from: legacy)
        XCTAssertEqual(old.magicTrickMode, .exactDateTime)
        XCTAssertEqual(old.specialDay.month, 12)
        XCTAssertEqual(old.specialDay.day, 25)
    }

    func testLegacyURLCarriesTheChosenDay() {
        let settings = CalculatorSettings()
        settings.magicTrickMode = .specialDay
        settings.specialDay = christmasEvening

        let fresh = CalculatorSettings()
        AppClipQuery.apply(AppClipQuery(settings: settings).url(), to: fresh)
        XCTAssertEqual(fresh.magicTrickMode, .specialDay)
        XCTAssertEqual(fresh.specialDay, christmasEvening)
    }
}
