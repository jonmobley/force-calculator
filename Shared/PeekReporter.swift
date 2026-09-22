import Combine
import Foundation

/// Debounces the spectator's typing and reports the settled value to the peek
/// service, so the performer sees the number even when the spectator never
/// presses equals.
///
/// A number is typed a digit at a time, so reporting every keystroke would send a
/// burst of requests that could arrive out of order. Instead the value is sent
/// once the spectator pauses. `flush` forces the pending value out immediately,
/// for the moment the calculator is closing and there is no time left to wait.
///
/// Must be used from the main thread: it is created as a `@StateObject` and every
/// call originates in a SwiftUI action.
public final class PeekReporter: ObservableObject {
    /// Delivers one settled value. Injected so tests need no network.
    public typealias Send = (String) -> Void

    private let send: Send
    private let debounceInterval: TimeInterval
    private var pending: DispatchWorkItem?
    private var lastReported: String?

    /// - Parameters:
    ///   - debounceInterval: Quiet period after the last keystroke before sending.
    ///   - send: Delivers the value. Defaults to a fire-and-forget upload that
    ///     swallows errors, since a dropped peek must never disturb the calculator.
    public init(
        debounceInterval: TimeInterval = 0.4,
        send: @escaping Send = { value in
            Task { try? await ForcePeekService.send(value) }
        }
    ) {
        self.debounceInterval = debounceInterval
        self.send = send
    }

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
            self?.deliver(display)
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    /// Sends the current display right away, cancelling any pending debounce.
    public func flush(_ display: String, enabled: Bool, suppressed: Bool) {
        guard shouldReport(display, enabled: enabled, suppressed: suppressed) else { return }
        pending?.cancel()
        pending = nil
        deliver(display)
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

    private func deliver(_ value: String) {
        guard value != lastReported else { return }
        lastReported = value
        send(value)
    }
}
