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

    /// Date and Time builds `MMDDYY` plus a four-digit time, which carries a tenth digit
    /// from October on and on any day past the ninth. The readout used to stop at nine, so
    /// those reveals came out as `1.122e9` and the trick died on screen.
    func testDateTimeRevealIsSpelledOutOnEveryDayOfTheYear() {
        for month in 1...12 {
            for day in [1, 9, 10, 28] {
                let moment = makeDate(month: month, day: day, hour: 18, minute: 30)
                for format in DateTimeFormat.allCases {
                    let number = DateTimeNumber.format(
                        moment.date,
                        format: format,
                        calendar: moment.calendar
                    )
                    let shown = CalculatorFormatter.formatResult(Double(number))
                    XCTAssertFalse(
                        shown.contains("e"),
                        "\(format.rawValue) on \(month)/\(day) fell back to \(shown)"
                    )
                }
            }
        }
    }

    /// The reveal is the whole effect, so a ten-digit force has to land on the display as a
    /// number the spectator can read back rather than as notation.
    func testEqualsSpellsOutATenDigitForce() {
        var state = CalculatorState()
        let handler = PerfectPlusHandler()
        state.display = "2"
        CalculatorOperations.performOperation(
            .add,
            state: &state,
            settings: CalculatorSettings(),
            perfectPlusHandler: handler
        )
        state.display = "2"
        state.userIsTyping = true
        CalculatorOperations.equals(
            state: &state,
            force: ForceValues(number: 1_122_260_630, activationCount: 1),
            perfectPlusHandler: handler
        )
        XCTAssertEqual(state.display, "1,122,260,630")
    }

    /// Past ten digits the readout has to give up, or a number too wide to fit would be
    /// squeezed into an unreadable line instead of an honest fallback.
    func testElevenDigitsStillFallBackToNotation() {
        XCTAssertEqual(CalculatorFormatter.formatResult(9_999_999_999), "9,999,999,999")
        XCTAssertTrue(CalculatorFormatter.formatResult(10_000_000_000).contains("e"))
    }

    func testPerfectPlusAddend() {
        XCTAssertEqual(PerfectPlusMath.perfectAddend(savedNumber: 100, forceNumber: 4_556_325), 4_556_225)
    }

    func testPerfectPlusOnlyPlusLeavesTheTrickPending() {
        XCTAssertTrue(PerfectPlusMath.shouldMarkPendingAdd(perfectPlusEnabled: true, isAdd: true))
        XCTAssertFalse(PerfectPlusMath.shouldMarkPendingAdd(perfectPlusEnabled: true, isAdd: false))
        XCTAssertFalse(PerfectPlusMath.shouldMarkPendingAdd(perfectPlusEnabled: false, isAdd: true))
    }

    /// Face-down is the move that hides the inert keypad, so it has to read cleanly whichever
    /// way the phone was rotated when it was turned over.
    func testScreenFaceFromGravity() {
        XCTAssertEqual(PerfectPlusMath.screenFace(gravityZ: 1), .down)
        XCTAssertEqual(PerfectPlusMath.screenFace(gravityZ: 0.6), .down)
        XCTAssertEqual(PerfectPlusMath.screenFace(gravityZ: -1), .up)
        XCTAssertEqual(PerfectPlusMath.screenFace(gravityZ: -0.5), .up)
        // Held on edge, between the two, so neither claim is made.
        XCTAssertNil(PerfectPlusMath.screenFace(gravityZ: 0))
        XCTAssertNil(PerfectPlusMath.screenFace(gravityZ: 0.3))
    }

    func testFaceDownWinsOverTheInPlaneAngle() {
        // Turned onto its face, whatever the rotation reads.
        XCTAssertEqual(PerfectPlusMath.turnTrigger(position: nil, face: .down), .faceDown)
        XCTAssertEqual(PerfectPlusMath.turnTrigger(position: .upright, face: .down), .faceDown)
        // Screen still up, so only a half-turn in the plane counts.
        XCTAssertEqual(
            PerfectPlusMath.turnTrigger(position: .upsideDown, face: .up),
            .planeRotation
        )
        XCTAssertNil(PerfectPlusMath.turnTrigger(position: .upright, face: .up))
        XCTAssertNil(PerfectPlusMath.turnTrigger(position: .sideways, face: .up))
        XCTAssertNil(PerfectPlusMath.turnTrigger(position: nil, face: .up))
    }

    /// Date and Time mode reads the clock live, and a minute can tick over between the reveal
    /// and the equals press. Equals has to land on the number the addend was built from, or
    /// the sum on screen does not add up.
    func testRevealLandsOnTheNumberTheAddendWasBuiltFrom() {
        var state = CalculatorState()
        let handler = PerfectPlusHandler()
        handler.markPendingAdd(operand: 100)

        handler.calculatePerfectAddend(
            state: &state,
            force: ForceValues(number: 922_261_259, activationCount: 3)
        )
        XCTAssertEqual(state.display, CalculatorFormatter.formatResult(922_261_159))

        // The clock rolls past the hour before equals is pressed.
        CalculatorOperations.equals(
            state: &state,
            force: ForceValues(number: 922_261_300, activationCount: 3),
            perfectPlusHandler: handler
        )
        XCTAssertEqual(state.display, CalculatorFormatter.formatResult(922_261_259))
    }

    /// The trick is armed with the phone on its face and a hand round the glass, so a stray
    /// press is likely. Clear was the last key still able to stand the trick down, and doing
    /// so cost a real performance the reveal.
    func testClearCannotStandDownAnArmedTrick() {
        var state = CalculatorState()
        state.display = "56"
        let handler = PerfectPlusHandler()
        handler.markPendingAdd(operand: 56)
        handler.mode = .armed

        CalculatorOperations.clearAll(state: &state, perfectPlusHandler: handler)
        XCTAssertEqual(handler.mode, .armed)
        XCTAssertEqual(state.display, "56")

        CalculatorOperations.clearEntry(state: &state, perfectPlusMode: handler.mode)
        XCTAssertEqual(state.display, "56")

        // Nothing is stranded: turning the phone back hands the keys over.
        handler.mode = .calculated
        CalculatorOperations.clearAll(state: &state, perfectPlusHandler: handler)
        XCTAssertEqual(handler.mode, .inactive)
        XCTAssertEqual(state.display, "0")
    }

    /// The number now goes up while the phone is still turned away, so the whole trick is
    /// sitting on a display nobody is watching. The keys have to stay as dead as they were
    /// while armed, or the same stray press that clear is protected from would type over it.
    func testStagedNumberIsAsProtectedAsAnArmedTrick() {
        XCTAssertTrue(PerfectPlusState.armed.keysAreInert)
        XCTAssertTrue(PerfectPlusState.staged.keysAreInert)
        XCTAssertFalse(PerfectPlusState.calculated.keysAreInert)
        XCTAssertFalse(PerfectPlusState.pendingAdd.keysAreInert)
        XCTAssertFalse(PerfectPlusState.inactive.keysAreInert)

        var state = CalculatorState()
        let handler = PerfectPlusHandler()
        handler.markPendingAdd(operand: 100)
        handler.calculatePerfectAddend(
            state: &state,
            force: ForceValues(number: 4_556_325, activationCount: 3)
        )
        let staged = state.display
        handler.mode = .staged

        CalculatorOperations.digitPressed("7", state: &state, perfectPlusMode: handler.mode)
        CalculatorOperations.backspace(state: &state, perfectPlusMode: handler.mode)
        CalculatorOperations.clearAll(state: &state, perfectPlusHandler: handler)
        XCTAssertEqual(state.display, staged)
        XCTAssertEqual(handler.mode, .staged)

        // Equals waits for the phone as well, so the force cannot land face down.
        CalculatorOperations.equals(
            state: &state,
            force: ForceValues(number: 4_556_325, activationCount: 3),
            perfectPlusHandler: handler
        )
        XCTAssertEqual(state.display, staged)
    }

    /// Correcting which move armed the trick has to be one-way. The in-plane angle reads as a
    /// half-turn both while the phone is turned onto its face and while it is turned back, so
    /// honouring it on the way back would strand the reveal.
    func testArmingCreditIsOnlyCorrectedTowardsFaceDown() {
        XCTAssertTrue(
            PerfectPlusMath.shouldReattribute(armedBy: .planeRotation, settled: .faceDown)
        )
        XCTAssertFalse(
            PerfectPlusMath.shouldReattribute(armedBy: .faceDown, settled: .planeRotation)
        )
        XCTAssertFalse(
            PerfectPlusMath.shouldReattribute(armedBy: .faceDown, settled: .faceDown)
        )
        XCTAssertFalse(
            PerfectPlusMath.shouldReattribute(armedBy: .planeRotation, settled: .planeRotation)
        )
    }

    /// Each move is undone by its own opposite. A phone armed on its face must not be
    /// revealed by a half-turn, which never brings the in-plane angle back upright anyway.
    func testReturnMirrorsTheMoveThatArmed() {
        XCTAssertTrue(PerfectPlusMath.hasReturned(from: .faceDown, position: nil, face: .up))
        XCTAssertFalse(PerfectPlusMath.hasReturned(from: .faceDown, position: .upright, face: .down))
        XCTAssertFalse(PerfectPlusMath.hasReturned(from: .faceDown, position: .upright, face: nil))

        XCTAssertTrue(PerfectPlusMath.hasReturned(from: .planeRotation, position: .upright, face: .up))
        XCTAssertFalse(PerfectPlusMath.hasReturned(from: .planeRotation, position: .upsideDown, face: .up))
        XCTAssertFalse(PerfectPlusMath.hasReturned(from: .planeRotation, position: nil, face: .up))
    }

    func testPlanePositionFromGravityHeldVertically() {
        XCTAssertEqual(PerfectPlusMath.planePosition(gravityX: 0, gravityY: -1), .upright)
        XCTAssertEqual(PerfectPlusMath.planePosition(gravityX: 0, gravityY: 1), .upsideDown)
        XCTAssertEqual(PerfectPlusMath.planePosition(gravityX: -1, gravityY: 0), .sideways)
        XCTAssertEqual(PerfectPlusMath.planePosition(gravityX: 1, gravityY: 0), .sideways)
    }

    /// Turned on a table the reading fell to 0.19, which an earlier 0.20 gate discarded even
    /// though the rotation itself was well past the upside-down mark.
    func testPlanePositionReadsATurnPerformedOnATable() {
        XCTAssertEqual(PerfectPlusMath.planePosition(gravityX: 0, gravityY: 0.19), .upsideDown)
        XCTAssertEqual(PerfectPlusMath.planePosition(gravityX: 0.13, gravityY: 0.14), .upsideDown)
        // Still short of the noise the same phone showed at rest.
        XCTAssertNil(PerfectPlusMath.planePosition(gravityX: 0, gravityY: 0.05))
        XCTAssertNil(PerfectPlusMath.planePosition(gravityX: 0.02, gravityY: 0.03))
    }

    /// Held out at a shallow angle for someone to tap, only a sliver of gravity lands in
    /// the screen plane, but it still says which way round the phone is.
    func testPlanePositionSurvivesShallowTilt() {
        // Upside down, roughly 13 degrees off flat.
        XCTAssertEqual(PerfectPlusMath.planePosition(gravityX: 0, gravityY: 0.22), .upsideDown)
        // Upside down and skewed 25 degrees, still well inside the band.
        XCTAssertEqual(PerfectPlusMath.planePosition(gravityX: 0.1, gravityY: 0.22), .upsideDown)
        // Upright at the same shallow angle.
        XCTAssertEqual(PerfectPlusMath.planePosition(gravityX: 0, gravityY: -0.22), .upright)
    }

    /// Flat enough that the in-plane direction is mostly noise, so the caller keeps
    /// whatever it last saw rather than trusting this.
    /// The trace leans on these numbers to explain a turn that did not arm, so they have to
    /// be reported even when the sample is too flat to classify.
    func testPlaneReadingReportsTheNumbersBehindTheVerdict() {
        let turned = PerfectPlusMath.planeReading(gravityX: 0, gravityY: 1)
        XCTAssertEqual(turned.position, .upsideDown)
        XCTAssertEqual(turned.degreesFromUpright, 180, accuracy: 0.5)
        XCTAssertEqual(turned.inPlaneGravity, 1, accuracy: 0.01)

        let level = PerfectPlusMath.planeReading(gravityX: 0, gravityY: 0.05)
        XCTAssertNil(level.position)
        XCTAssertEqual(level.inPlaneGravity, 0.05, accuracy: 0.01)
    }

    func testPlanePositionIsUnknownWhenNearlyLevel() {
        XCTAssertNil(PerfectPlusMath.planePosition(gravityX: 0, gravityY: 0.1))
        XCTAssertNil(PerfectPlusMath.planePosition(gravityX: 0.05, gravityY: -0.05))
        XCTAssertNil(PerfectPlusMath.planePosition(gravityX: 0, gravityY: 0))
    }

    func testPlanePositionFallbackCannotReadTiltedPhone() {
        XCTAssertEqual(PerfectPlusMath.planePosition(.portraitUpsideDown), .upsideDown)
        XCTAssertEqual(PerfectPlusMath.planePosition(.portrait), .upright)
        XCTAssertEqual(PerfectPlusMath.planePosition(.landscapeLeft), .sideways)
        XCTAssertNil(PerfectPlusMath.planePosition(.faceUp))
        XCTAssertNil(PerfectPlusMath.planePosition(.faceDown))
        XCTAssertNil(PerfectPlusMath.planePosition(.unknown))
    }

    func testAppClipURLRoundTrip() {
        let settings = CalculatorSettings()
        settings.forceNumber = 77
        settings.activationCount = 4
        settings.magicTrickMode = .exactDateTime
        settings.dateTimeFormat = .xxDDMMYY
        settings.buttonTheme = .pink
        settings.perfectPlusEnabled = true
        settings.perfectPlusHapticsEnabled = false
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
        XCTAssertTrue(fresh.perfectPlusEnabled)
        XCTAssertFalse(fresh.perfectPlusHapticsEnabled)
        XCTAssertTrue(fresh.startWithScreenshot)
        XCTAssertEqual(settings.forceNumber, 77)
    }

    func testSettingsJSONRoundTripKeepsLaunchFlags() {
        let settings = CalculatorSettings()
        settings.forceNumber = 42
        settings.perfectPlusEnabled = true
        settings.startWithScreenshot = true
        settings.dateTimeFormat = .ddMMYY

        let data = try? JSONEncoder().encode(settings)
        guard let data, let decoded = try? JSONDecoder().decode(CalculatorSettings.self, from: data) else {
            XCTFail("Settings JSON did not round-trip")
            return
        }
        XCTAssertEqual(decoded.forceNumber, 42)
        XCTAssertTrue(decoded.perfectPlusEnabled)
        XCTAssertTrue(decoded.startWithScreenshot)
        XCTAssertEqual(decoded.dateTimeFormat, .ddMMYY)

        let live = CalculatorSettings()
        live.applyStored(decoded)
        XCTAssertTrue(live.startWithScreenshot)
        XCTAssertTrue(live.perfectPlusEnabled)
    }

    /// Silencing the vibration has to survive the trip to the clip, and a record written
    /// before the switch existed has to keep the buzz the performer already relies on.
    func testPerfectPlusVibrationRoundTripsAndDefaultsOn() throws {
        XCTAssertTrue(CalculatorSettings().perfectPlusHapticsEnabled)

        let settings = CalculatorSettings()
        settings.perfectPlusEnabled = true
        settings.perfectPlusHapticsEnabled = false
        let data = try JSONEncoder().encode(settings.snapshot())
        let decoded = try JSONDecoder().decode(CalculatorSettings.self, from: data)
        XCTAssertFalse(decoded.perfectPlusHapticsEnabled)

        let legacy = Data(#"{"theme":"dark","forceNumber":1,"activationCount":3,"#.utf8)
            + Data(#""currentCount":0,"magicTrickMode":"Force Number"}"#.utf8)
        let old = try JSONDecoder().decode(CalculatorSettings.self, from: legacy)
        XCTAssertTrue(old.perfectPlusHapticsEnabled)
    }

    func testAutosaveCoalescesEditsIntoOneWrite() {
        let suite = privateSettingsSuite()
        let key = CalculatorSettings.userDefaultsKey

        let settings = CalculatorSettings()
        settings.defaultsStore = suite
        settings.beginAutosave()
        settings.forceNumber = 1234
        settings.activationCount = 7
        settings.buttonTheme = .purple
        XCTAssertNil(suite.data(forKey: key), "A burst of edits should not write once per edit")

        settings.flushPendingSave()
        let reloaded = CalculatorSettings()
        reloaded.defaultsStore = suite
        reloaded.loadSettings()
        XCTAssertEqual(reloaded.forceNumber, 1234)
        XCTAssertEqual(reloaded.activationCount, 7)
        XCTAssertEqual(reloaded.buttonTheme, .purple)
    }

    func testAutosaveWritesAfterCoalescingWindow() {
        let suite = privateSettingsSuite()
        let key = CalculatorSettings.userDefaultsKey

        let settings = CalculatorSettings()
        settings.defaultsStore = suite
        settings.beginAutosave()
        settings.forceNumber = 5678

        let written = expectation(description: "autosave wrote without an explicit flush")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if suite.data(forKey: key) != nil { written.fulfill() }
        }
        wait(for: [written], timeout: 3)

        let reloaded = CalculatorSettings()
        reloaded.defaultsStore = suite
        reloaded.loadSettings()
        XCTAssertEqual(reloaded.forceNumber, 5678)
    }

    /// A suite the host app does not use, so these tests can run beside it.
    private func privateSettingsSuite() -> UserDefaults {
        let name = "ForceTests.autosave.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        addTeardownBlock { suite.removePersistentDomain(forName: name) }
        return suite
    }

    /// The whole point of the config service: a written sticker must keep working
    /// after the performer edits their setup.
    func testStableURLDoesNotChangeWhenSettingsChange() {
        let settings = CalculatorSettings()
        settings.forceNumber = 1111
        settings.magicTrickMode = .forceNumber
        settings.buttonTheme = .blue
        let before = AppClipQuery.stableURL(performer: "abc123")

        settings.forceNumber = 9999
        settings.magicTrickMode = .exactDateTime
        settings.buttonTheme = .orange
        XCTAssertEqual(AppClipQuery.stableURL(performer: "abc123"), before)
    }

    /// The clip has no identity of its own, so the URL is the only thing that can tell it
    /// whose record to read. A tag pointing at the wrong performer forces the wrong number.
    func testStableURLRoundTripsThePerformer() {
        let url = AppClipQuery.stableURL(performer: "aBc-123_xyz")
        XCTAssertEqual(AppClipQuery.performerID(in: url), "aBc-123_xyz")
    }

    /// Stickers written before performers had their own ids carry no `id` at all, and
    /// have to keep resolving to the record they were always pointing at.
    func testAnInvocationWithoutAnIDFallsBackToTheSharedRecord() {
        let legacy = AppClipQuery(settings: CalculatorSettings()).url()
        XCTAssertEqual(AppClipQuery.performerID(in: legacy), PerformerID.shared)
    }

    /// The service keys its table on this value, so anything outside its alphabet has to
    /// be refused here rather than sent and rejected.
    func testAMalformedPerformerIsNotTrusted() {
        var components = URLComponents(url: AppClipQuery.invocation, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: "not a valid id")]
        XCTAssertEqual(AppClipQuery.performerID(in: components.url!), PerformerID.shared)
    }

    func testStableURLCarriesNoSettings() {
        let items = URLComponents(
            url: AppClipQuery.stableURL(performer: "abc123"),
            resolvingAgainstBaseURL: false
        )?.queryItems ?? []
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
        settings.perfectPlusEnabled = true
        settings.perfectPlusHapticsEnabled = false

        let payload = try JSONEncoder().encode(settings.snapshot())
        let decoded = try JSONDecoder().decode(CalculatorSettings.self, from: payload)

        XCTAssertEqual(decoded.forceNumber, 8675309)
        XCTAssertEqual(decoded.activationCount, 5)
        XCTAssertEqual(decoded.magicTrickMode, .exactDateTime)
        XCTAssertEqual(decoded.dateTimeFormat, .xxDDMMYY)
        XCTAssertEqual(decoded.buttonTheme, .purple)
        XCTAssertTrue(decoded.perfectPlusEnabled)
        XCTAssertFalse(decoded.perfectPlusHapticsEnabled)
    }

    private func makeDate(
        month: Int = 1,
        day: Int = 2,
        hour: Int,
        minute: Int
    ) -> (date: Date, calendar: Calendar) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var parts = DateComponents()
        parts.calendar = calendar
        parts.timeZone = calendar.timeZone
        parts.year = 2026
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        return (calendar.date(from: parts)!, calendar)
    }
}
