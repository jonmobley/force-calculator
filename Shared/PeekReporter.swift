import Combine
import Foundation

/// Reports the spectator's calculation to the peek service as they work through it, so
/// the performer sees what they did and not just the number left on screen at the end.
///
/// A number is typed a digit at a time, so reporting every keystroke would send a burst
/// of requests that could arrive out of order. The live number is therefore sent once
/// typing settles. Pressing an operator is different: it means the number is final, so
/// that goes immediately, carrying the key that ended it.
///
/// Both reports for one number share an entry id, so the second updates the first rather
/// than adding a second row. That is what turns `123` into `123 +` on the performer's
/// screen instead of listing the same number twice.
///
/// Must be used from the main thread: it is created as a `@StateObject` and every
/// call originates in a SwiftUI action.
public final class PeekReporter: ObservableObject {
    /// Delivers one entry. Injected so tests need no network.
    public typealias Send = (_ value: String, _ entryID: String, _ op: String?) -> Void

    /// Whose record the spectator's numbers belong in.
    ///
    /// Settable rather than fixed at init: the clip learns which performer it is running
    /// for from the invocation URL, which can arrive after the calculator is on screen.
    public var performerID = PerformerID.shared

    private let send: Send?
    private let debounceInterval: TimeInterval
    private var pending: DispatchWorkItem?
    private var lastReported: String?

    /// Distinguishes this run from the last, so a clip relaunched for a new spectator
    /// cannot collide with entries the previous one wrote.
    private let sessionToken = PerformerID.generate()
    private var entryIndex = 0

    /// - Parameters:
    ///   - debounceInterval: Quiet period after the last keystroke before sending.
    ///   - send: Delivers the entry. Left nil in the app, where it goes to the peek
    ///     service as a fire-and-forget upload that swallows errors, since a dropped
    ///     peek must never disturb the calculator. Tests pass their own.
    public init(
        debounceInterval: TimeInterval = 0.4,
        send: Send? = nil
    ) {
        self.debounceInterval = debounceInterval
        self.send = send
    }

    /// The entry the live number is being written to. Stays put until an operator
    /// closes it, so the digits of one number keep overwriting a single row.
    private var currentEntryID: String { "\(sessionToken)-\(entryIndex)" }

    /// Schedules the current display to be reported once typing settles.
    ///
    /// - Parameters:
    ///   - display: The current readout, grouping and all.
    ///   - enabled: Whether live peek is on for this session.
    ///   - suppressed: True while the performer's own covert setup is on screen,
    ///     which must never be reported as if it were the spectator's number.
    public func report(_ display: String, enabled: Bool, suppressed: Bool) {
        guard shouldReport(display, enabled: enabled, suppressed: suppressed) else { return }
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.deliver(display, op: nil)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// Reports the number an operator has just ended, and moves on to the next one.
    ///
    /// Sent without waiting: the key press already says the number is finished, and a
    /// debounce here would let the next number start before this one had been recorded.
    public func close(_ display: String, with op: String, enabled: Bool, suppressed: Bool) {
        guard shouldReport(display, enabled: enabled, suppressed: suppressed) else { return }
        pending?.cancel()
        pending = nil
        deliver(display, op: op)
        // Whatever the spectator types next is a new number, so it needs its own entry.
        entryIndex += 1
        lastReported = nil
    }

    /// Sends the current display right away, cancelling any pending debounce.
    public func flush(_ display: String, enabled: Bool, suppressed: Bool) {
        guard shouldReport(display, enabled: enabled, suppressed: suppressed) else { return }
        pending?.cancel()
        pending = nil
        deliver(display, op: nil)
    }

    /// Starts a fresh entry without reporting anything, so what the spectator types next
    /// does not overwrite the number already on the performer's screen. Used by clear,
    /// where the display is wiped but nothing was finished.
    public func beginNewEntry() {
        pending?.cancel()
        pending = nil
        guard lastReported != nil else { return }
        entryIndex += 1
        lastReported = nil
    }

    /// Drops any pending report. Called when the calculator closes.
    public func stop() {
        pending?.cancel()
        pending = nil
    }

    // MARK: - Helpers

    /// A resting "0" is the empty state, not something the spectator typed, so it
    /// is never worth a request.
    private func shouldReport(_ display: String, enabled: Bool, suppressed: Bool) -> Bool {
        enabled && !suppressed && display != "0"
    }

    private func deliver(_ value: String, op: String?) {
        // An operator always goes out, even on a value already sent, because it is the
        // operator itself that is new.
        if op == nil, value == lastReported { return }
        lastReported = value
        let entryID = currentEntryID
        guard let send else {
            let id = performerID
            Task { try? await ForcePeekService.send(value, entryID: entryID, op: op, id: id) }
            return
        }
        send(value, entryID, op)
    }
}
