import XCTest
import ForceShared
@testable import Force

/// Covers the saved force numbers list: its limit, uniqueness, names, order, the one-time
/// seed, and that it survives a relaunch without ever joining the published settings.
@MainActor
final class SavedForceNumbersTests: XCTestCase {
    private var suiteName = ""
    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SavedForceNumbersTests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Adding

    func testAddsNamedEntriesInOrder() {
        let saved = SavedForceNumbers(store: suite)
        XCTAssertTrue(saved.add(label: "Birthday", number: 4_556_325))
        XCTAssertTrue(saved.add(label: "  Phone  ", number: 5_551_234))

        XCTAssertEqual(saved.entries.map(\.label), ["Birthday", "Phone"])
        XCTAssertEqual(saved.entries.first?.title, "Birthday – 4556325")
    }

    func testABlankNameReadsAsTheNumber() throws {
        let saved = SavedForceNumbers(store: suite)
        saved.add(label: "   ", number: 42)
        let entry = try XCTUnwrap(saved.entries.first)
        XCTAssertEqual(entry.label, "42")
        XCTAssertEqual(entry.title, "42")
        XCTAssertFalse(entry.hasName)
    }

    func testRefusesADuplicateNumber() {
        let saved = SavedForceNumbers(store: suite)
        XCTAssertTrue(saved.add(label: "One", number: 7))
        XCTAssertFalse(saved.add(label: "Two", number: 7))
        XCTAssertEqual(saved.entries.count, 1)
    }

    func testStopsAtTheLimit() {
        let saved = SavedForceNumbers(store: suite)
        for number in 1...SavedForceNumbers.limit {
            XCTAssertTrue(saved.add(label: "N\(number)", number: number))
        }
        XCTAssertTrue(saved.isFull)
        XCTAssertFalse(saved.add(label: "Extra", number: 999))
        XCTAssertEqual(saved.entries.count, SavedForceNumbers.limit)
    }

    func testBringsANumberIntoRange() {
        let saved = SavedForceNumbers(store: suite)
        saved.add(label: "Big", number: 123_456_789_012)
        XCTAssertEqual(saved.entries.first?.number, CalculatorSettings.forceNumberRange.upperBound)
    }

    // MARK: - Editing

    func testRenamesMovesAndDeletes() throws {
        let saved = SavedForceNumbers(store: suite)
        saved.add(label: "A", number: 1)
        saved.add(label: "B", number: 2)
        saved.add(label: "C", number: 3)

        saved.rename(try XCTUnwrap(saved.entries.first).id, to: "First")
        saved.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        saved.remove(atOffsets: IndexSet(integer: 2))

        XCTAssertEqual(saved.entries.map(\.label), ["C", "First"])
    }

    // MARK: - Storage

    func testSurvivesARelaunch() {
        let saved = SavedForceNumbers(store: suite)
        saved.add(label: "Birthday", number: 4_556_325)
        saved.add(label: "Phone", number: 5_551_234)

        let reloaded = SavedForceNumbers(store: suite)
        XCTAssertEqual(reloaded.entries, saved.entries)
    }

    func testSeedsWithTheCurrentNumberOnlyOnce() {
        let saved = SavedForceNumbers(store: suite)
        saved.seedIfNeeded(with: 4_556_325)
        XCTAssertEqual(saved.entries.map(\.number), [4_556_325])

        saved.remove(atOffsets: IndexSet(integer: 0))
        let relaunched = SavedForceNumbers(store: suite)
        relaunched.seedIfNeeded(with: 1234)
        XCTAssertTrue(relaunched.entries.isEmpty)
    }

    func testTheListIsNeverPartOfThePublishedSettings() throws {
        let saved = SavedForceNumbers(store: suite)
        saved.add(label: "Secret Birthday", number: 4_556_325)
        let settings = CalculatorSettings()
        settings.forceNumber = 4_556_325

        let published = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
        XCTAssertFalse(published.contains("Secret Birthday"))
        XCTAssertFalse(published.contains("savedForceNumbers"))
    }
}
