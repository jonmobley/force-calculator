import XCTest
import ForceShared
@testable import Force

/// Covers the saved Special Days list: its limit, uniqueness, names, order, the holiday
/// presets, and that it survives a relaunch without ever joining the published settings.
@MainActor
final class SavedSpecialDaysTests: XCTestCase {
    private var suiteName = ""
    private var suite: UserDefaults!

    private let anniversary = SpecialDay(year: 2027, month: 6, day: 12, hour: 18, minute: 0)

    override func setUp() {
        super.setUp()
        suiteName = "SavedSpecialDaysTests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Adding

    func testAddsNamedEntriesAndRefusesDuplicates() {
        let saved = SavedSpecialDays(store: suite)
        XCTAssertTrue(saved.add(label: "  Anniversary  ", day: anniversary))
        XCTAssertFalse(saved.add(label: "Again", day: anniversary))

        XCTAssertEqual(saved.entries.map(\.label), ["Anniversary"])
        XCTAssertTrue(saved.entries[0].hasName)
    }

    func testABlankNameReadsAsTheDate() throws {
        let saved = SavedSpecialDays(store: suite)
        saved.add(label: "   ", day: anniversary)
        let entry = try XCTUnwrap(saved.entries.first)
        XCTAssertEqual(entry.label, anniversary.displayText)
        XCTAssertFalse(entry.hasName)
    }

    func testStopsAtTheLimit() {
        let saved = SavedSpecialDays(store: suite)
        for minute in 0..<SavedSpecialDays.limit {
            XCTAssertTrue(saved.add(label: "", day: SpecialDay(year: 2027, month: 1, day: 1, minute: minute)))
        }
        XCTAssertTrue(saved.isFull)
        XCTAssertFalse(saved.add(label: "Extra", day: anniversary))
    }

    // MARK: - Editing

    func testRenameReorderAndRemoveSurviveARelaunch() {
        let saved = SavedSpecialDays(store: suite)
        let other = SpecialDay(year: 2027, month: 2, day: 3)
        saved.add(label: "First", day: anniversary)
        saved.add(label: "Second", day: other)
        saved.rename(saved.entries[0].id, to: "Renamed")
        saved.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        let relaunched = SavedSpecialDays(store: suite)
        XCTAssertEqual(relaunched.entries.map(\.label), ["Second", "Renamed"])

        relaunched.remove(atOffsets: IndexSet(integer: 0))
        XCTAssertEqual(SavedSpecialDays(store: suite).entries.map(\.label), ["Renamed"])
    }

    /// The list is private repertoire; only the chosen day goes to the config service.
    func testSavedDaysNeverJoinThePublishedSettings() throws {
        let saved = SavedSpecialDays(store: suite)
        saved.add(label: "Secret Anniversary", day: anniversary)

        let settings = CalculatorSettings()
        settings.specialDay = anniversary
        let payload = try XCTUnwrap(String(data: JSONEncoder().encode(settings), encoding: .utf8))
        XCTAssertFalse(payload.contains("Secret Anniversary"))
    }

    // MARK: - Holidays

    func testHolidaysAreDatedToTheirNextOccurrence() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27))!
        let holidays = SpecialDayHoliday.upcoming(now: now, calendar: calendar)

        XCTAssertEqual(holidays.first { $0.name == "Halloween" }?.day.year, 2026)
        XCTAssertEqual(holidays.first { $0.name == "New Year's Day" }?.day.year, 2027)
        XCTAssertEqual(
            holidays.first { $0.name == "Pi Day" }?.day,
            SpecialDay(year: 2027, month: 3, day: 14, hour: 13, minute: 59)
        )
    }
}
