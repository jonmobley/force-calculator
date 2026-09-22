import XCTest
import ForceShared

final class ForceLogicTests: XCTestCase {
    func testForceAppearsOnlyAfterActivationCount() {
        let count = 0
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

    func testPlusPerfectAddend() {
        XCTAssertEqual(PlusPerfectMath.perfectAddend(savedNumber: 100, forceNumber: 4_556_325), 4_556_225)
    }

    func testPlusPerfectOnlyPlusLeavesTheTrickPending() {
        XCTAssertTrue(PlusPerfectMath.shouldMarkPendingAdd(plusPerfectEnabled: true, isAdd: true))
        XCTAssertFalse(PlusPerfectMath.shouldMarkPendingAdd(plusPerfectEnabled: true, isAdd: false))
        XCTAssertFalse(PlusPerfectMath.shouldMarkPendingAdd(plusPerfectEnabled: false, isAdd: true))
    }

    func testPlusPerfectArmsOnlyWhenTurnedOverWithPlusPending() {
        XCTAssertTrue(PlusPerfectMath.shouldArm(mode: .pendingAdd, heldOrientation: .portraitUpsideDown))
        XCTAssertFalse(PlusPerfectMath.shouldArm(mode: .pendingAdd, heldOrientation: .portrait))
        XCTAssertFalse(PlusPerfectMath.shouldArm(mode: .pendingAdd, heldOrientation: .landscapeLeft))
        // No pending plus means turning the phone over does nothing at all.
        XCTAssertFalse(PlusPerfectMath.shouldArm(mode: .inactive, heldOrientation: .portraitUpsideDown))
        XCTAssertFalse(PlusPerfectMath.shouldArm(mode: .armed, heldOrientation: .portraitUpsideDown))
        XCTAssertFalse(PlusPerfectMath.shouldArm(mode: .calculated, heldOrientation: .portraitUpsideDown))
    }

    func testPlusPerfectIgnoresFlatOrientations() {
        XCTAssertEqual(PlusPerfectMath.heldOrientation(.portraitUpsideDown), .portraitUpsideDown)
        XCTAssertEqual(PlusPerfectMath.heldOrientation(.landscapeLeft), .landscapeLeft)
        XCTAssertNil(PlusPerfectMath.heldOrientation(.faceUp))
        XCTAssertNil(PlusPerfectMath.heldOrientation(.faceDown))
        XCTAssertNil(PlusPerfectMath.heldOrientation(.unknown))
    }

    func testPlusPerfectRevealsOnlyOnUprightPortraitWhileArmed() {
        XCTAssertTrue(PlusPerfectMath.shouldReveal(mode: .armed, heldOrientation: .portrait))
        XCTAssertFalse(PlusPerfectMath.shouldReveal(mode: .armed, heldOrientation: .landscapeRight))
        XCTAssertFalse(PlusPerfectMath.shouldReveal(mode: .armed, heldOrientation: .portraitUpsideDown))
        XCTAssertFalse(PlusPerfectMath.shouldReveal(mode: .inactive, heldOrientation: .portrait))
        XCTAssertFalse(PlusPerfectMath.shouldReveal(mode: .pendingAdd, heldOrientation: .portrait))
        XCTAssertFalse(PlusPerfectMath.shouldReveal(mode: .calculated, heldOrientation: .portrait))
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

    func testAutosaveCoalescesEditsIntoOneWrite() {
        let suite = UserDefaults(suiteName: CalculatorSettings.appGroup) ?? .standard
        let key = CalculatorSettings.userDefaultsKey
        let original = suite.data(forKey: key)
        defer {
            if let original {
                suite.set(original, forKey: key)
            } else {
                suite.removeObject(forKey: key)
            }
        }
        suite.removeObject(forKey: key)

        let settings = CalculatorSettings()
        settings.beginAutosave()
        settings.forceNumber = 1234
        settings.activationCount = 7
        settings.buttonTheme = .purple
        XCTAssertNil(suite.data(forKey: key), "A burst of edits should not write once per edit")

        settings.flushPendingSave()
        let reloaded = CalculatorSettings()
        reloaded.loadSettings()
        XCTAssertEqual(reloaded.forceNumber, 1234)
        XCTAssertEqual(reloaded.activationCount, 7)
        XCTAssertEqual(reloaded.buttonTheme, .purple)
    }

    func testAutosaveWritesAfterCoalescingWindow() {
        let suite = UserDefaults(suiteName: CalculatorSettings.appGroup) ?? .standard
        let key = CalculatorSettings.userDefaultsKey
        let original = suite.data(forKey: key)
        defer {
            if let original {
                suite.set(original, forKey: key)
            } else {
                suite.removeObject(forKey: key)
            }
        }
        suite.removeObject(forKey: key)

        let settings = CalculatorSettings()
        settings.beginAutosave()
        settings.forceNumber = 5678

        let written = expectation(description: "autosave wrote without an explicit flush")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if suite.data(forKey: key) != nil { written.fulfill() }
        }
        wait(for: [written], timeout: 3)

        let reloaded = CalculatorSettings()
        reloaded.loadSettings()
        XCTAssertEqual(reloaded.forceNumber, 5678)
    }

    /// The whole point of the config service: a written sticker must keep working
    /// after the performer edits their setup.
    func testStableURLDoesNotChangeWhenSettingsChange() {
        let settings = CalculatorSettings()
        settings.forceNumber = 1111
        settings.magicTrickMode = .forceNumber
        settings.buttonTheme = .blue
        let before = AppClipQuery.stableURL()

        settings.forceNumber = 9999
        settings.magicTrickMode = .exactDateTime
        settings.buttonTheme = .orange
        XCTAssertEqual(AppClipQuery.stableURL(), before)
    }

    func testStableURLCarriesNoSettings() {
        let items = URLComponents(url: AppClipQuery.stableURL(), resolvingAgainstBaseURL: false)?
            .queryItems ?? []
        let names = Set(items.map(\.name))

        XCTAssertEqual(names, ["p", "id"])
        for leaked in ["fn", "ac", "mt", "dt", "bt", "pp", "sws"] {
            XCTAssertFalse(names.contains(leaked), "\(leaked) must not be written onto the tag")
        }
        XCTAssertEqual(
            items.first { $0.name == "p" }?.value,
            AppClipQuery.clipBundleIdentifier
        )
    }

    /// Stickers written before the config service existed still carry settings,
    /// and must keep working.
    func testLegacyURLStillCarriesSettings() {
        let settings = CalculatorSettings()
        settings.forceNumber = 4242
        settings.magicTrickMode = .exactDateTime

        let names = Set(
            URLComponents(url: AppClipQuery(settings: settings).url(), resolvingAgainstBaseURL: false)?
                .queryItems?.map(\.name) ?? []
        )
        XCTAssertTrue(names.isSuperset(of: ["p", "fn", "ac", "mt", "dt", "bt", "pp", "sws"]))
    }

    func testSnapshotIsDetachedFromLaterEdits() {
        let settings = CalculatorSettings()
        settings.forceNumber = 100
        settings.buttonTheme = .green

        let snapshot = settings.snapshot()
        settings.forceNumber = 200
        settings.buttonTheme = .pink

        XCTAssertEqual(snapshot.forceNumber, 100)
        XCTAssertEqual(snapshot.buttonTheme, .green)
    }

    /// The clip decodes exactly what the app publishes, so the two must agree.
    func testPublishedPayloadDecodesBackIntoSettings() throws {
        let settings = CalculatorSettings()
        settings.forceNumber = 8675309
        settings.activationCount = 5
        settings.magicTrickMode = .exactDateTime
        settings.dateTimeFormat = .xxDDMMYY
        settings.buttonTheme = .purple
        settings.plusPerfectEnabled = true

        let payload = try JSONEncoder().encode(settings.snapshot())
        let decoded = try JSONDecoder().decode(CalculatorSettings.self, from: payload)

        XCTAssertEqual(decoded.forceNumber, 8675309)
        XCTAssertEqual(decoded.activationCount, 5)
        XCTAssertEqual(decoded.magicTrickMode, .exactDateTime)
        XCTAssertEqual(decoded.dateTimeFormat, .xxDDMMYY)
        XCTAssertEqual(decoded.buttonTheme, .purple)
        XCTAssertTrue(decoded.plusPerfectEnabled)
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
