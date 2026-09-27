import XCTest
import ForceShared

/// Covers ordered delivery and the single retry. The upload is injected, so these
/// run without the network.
final class PeekUploaderTests: XCTestCase {
    private struct Sent: Equatable {
        let value: String
        let entryID: String
    }

    func testAFailedSendIsRetried() async {
        final class Box: @unchecked Sendable {
            var tries = 0
            var sent: [Sent] = []
        }
        let box = Box()
        let uploader = PeekUploader(liveRetryDelays: [.zero]) { value, entryID, _, _ in
            box.tries += 1
            if box.tries == 1 { throw URLError(.networkConnectionLost) }
            box.sent.append(Sent(value: value, entryID: entryID))
        }

        await uploader.submit(value: "42", entryID: "e", op: nil, id: "p")

        XCTAssertEqual(box.tries, 2)
        XCTAssertEqual(box.sent, [Sent(value: "42", entryID: "e")])
    }

    /// The operator-close send has no follow-up keystroke to fix a lost upload, so it
    /// gets its own longer retry schedule: a live drop self-heals, a closed one does not.
    func testAClosedEntryGetsMoreRetriesThanALiveOne() async {
        final class Box: @unchecked Sendable {
            var tries = 0
            var sent: [Sent] = []
        }
        let box = Box()
        let uploader = PeekUploader(
            liveRetryDelays: [.zero],
            closedRetryDelays: [.zero, .zero, .zero]
        ) { value, entryID, _, _ in
            box.tries += 1
            if box.tries < 4 { throw URLError(.networkConnectionLost) }
            box.sent.append(Sent(value: value, entryID: entryID))
        }

        await uploader.submit(value: "123", entryID: "e", op: "+", id: "p")

        XCTAssertEqual(box.tries, 4, "closed entries retry up to their own longer schedule")
        XCTAssertEqual(box.sent, [Sent(value: "123", entryID: "e")])
    }

    /// A live send that fails past its own budget must give up rather than borrowing the
    /// closed schedule, since a next keystroke will resend anyway.
    func testALiveEntryDoesNotUseTheClosedRetryBudget() async {
        final class Box: @unchecked Sendable { var tries = 0 }
        let box = Box()
        let uploader = PeekUploader(
            liveRetryDelays: [.zero],
            closedRetryDelays: [.zero, .zero, .zero]
        ) { _, _, _, _ in
            box.tries += 1
            throw URLError(.networkConnectionLost)
        }

        await uploader.submit(value: "42", entryID: "e", op: nil, id: "p")

        XCTAssertEqual(box.tries, 2, "live retries stop after the live budget is spent")
    }

    /// A request already on the wire still finishes. The replacement goes next, so
    /// the service ends on the number the spectator actually reached.
    func testANewerValueFollowsTheOneAlreadyInFlight() async {
        final class Box: @unchecked Sendable {
            var uploader: PeekUploader?
            var sent: [String] = []
        }
        let box = Box()
        let uploader = PeekUploader(liveRetryDelays: [], closedRetryDelays: []) { value, _, _, id in
            if value == "1" {
                await box.uploader?.submit(value: "12", entryID: "e", op: nil, id: id)
            }
            box.sent.append(value)
        }
        box.uploader = uploader

        await uploader.submit(value: "1", entryID: "e", op: nil, id: "p")

        XCTAssertEqual(box.sent, ["1", "12"])
    }

    func testTheNextNumberWaitsForTheOneBeforeIt() async {
        final class Box: @unchecked Sendable {
            var uploader: PeekUploader?
            var sent: [String] = []
        }
        let box = Box()
        let uploader = PeekUploader(liveRetryDelays: [], closedRetryDelays: []) { value, _, _, id in
            if value == "123" {
                await box.uploader?.submit(value: "456", entryID: "b", op: nil, id: id)
            }
            box.sent.append(value)
        }
        box.uploader = uploader

        await uploader.submit(value: "123", entryID: "a", op: "+", id: "p")

        XCTAssertEqual(box.sent, ["123", "456"])
    }

    /// After the retry is spent, a later number still has its own attempts.
    func testGivingUpDoesNotBlockTheNextNumber() async {
        final class Box: @unchecked Sendable {
            var fail = true
            var sent: [String] = []
        }
        let box = Box()
        let uploader = PeekUploader(liveRetryDelays: [.zero]) { value, _, _, _ in
            if box.fail { throw URLError(.networkConnectionLost) }
            box.sent.append(value)
        }

        await uploader.submit(value: "1", entryID: "a", op: nil, id: "p")
        box.fail = false
        await uploader.submit(value: "2", entryID: "b", op: nil, id: "p")

        XCTAssertEqual(box.sent, ["2"])
    }
}
