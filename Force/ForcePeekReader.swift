import Combine
import Foundation
import ForceShared

/// Polls the peek service for the number the spectator is typing and publishes it
/// for the performer's UI.
///
/// Runs only while the performer is watching and live peek is on. Reading is gated on
/// the write token the app holds for its own record, so a refusal surfaces as its own
/// state rather than a silent blank. Transient network errors keep the last value on
/// screen instead of flickering it away between polls.
@MainActor
final class ForcePeekReader: ObservableObject {
    enum State: Equatable {
        /// Not polling.
        case idle
        /// Polling, but the spectator has not typed anything yet.
        case waiting
        /// The calculation the spectator has worked through, oldest first.
        case value(ForcePeekService.Peek)
        /// The service refused the read, so this performer's credentials are not the
        /// ones that claimed the record. Nothing the performer can fix in the moment.
        case notAuthorized
    }

    /// How often the readout asks the service. The wait is measured from the start
    /// of a poll, so a slow reply does not add a second gap on top of itself.
    private static let pollInterval: Duration = .milliseconds(500)

    /// A peek older than this is treated as nothing.
    ///
    /// Matches the service, which keeps a calculation for ten minutes. A shorter
    /// window blanked the readout while a spectator was only thinking. Between
    /// spectators the performer clears it; this limit is the backstop when they
    /// do not. Compares the service clock against the device's, so a few seconds
    /// of skew is fine at this scale.
    /// Nonisolated so `freshValue` can default to it: that helper is pure and callable
    /// off the main actor, and the value never changes.
    nonisolated static let staleAfter: TimeInterval = 10 * 60

    @Published private(set) var state: State = .idle

    private var task: Task<Void, Never>?

    /// Begins polling. Safe to call repeatedly; a second call is a no-op.
    func start() {
        guard task == nil else { return }
        state = .waiting
        task = Task { [weak self] in await self?.loop() }
    }

    /// Stops polling and clears the readout.
    func stop() {
        task?.cancel()
        task = nil
        state = .idle
    }

    /// Wipes the calculation on the service so the next spectator starts clean, rather
    /// than the performer waiting out the age limit between people.
    func clear() async {
        let credentials = PerformerCredentials.current()
        do {
            try await ForcePeekService.clear(
                id: credentials.identifier,
                token: credentials.writeToken
            )
            state = task == nil ? .idle : .waiting
        } catch {
            debugLog("👁️ Peek clear failed: \(error)")
        }
    }

    deinit {
        task?.cancel()
    }

    /// The peek to show, or nil when there is none fresh enough to trust.
    ///
    /// Pure so the age rule can be tested without the network.
    static func freshValue(
        _ peek: ForcePeekService.Peek?,
        now: Date = Date(),
        staleAfter: TimeInterval = staleAfter
    ) -> ForcePeekService.Peek? {
        guard let peek else { return nil }
        let age = now.timeIntervalSince(peek.updatedAt)
        // A negative age is clock skew, not staleness, so keep the value.
        return age <= staleAfter ? peek : nil
    }

    private func loop() async {
        while !Task.isCancelled {
            let started = ContinuousClock.now
            await poll()
            let remaining = Self.pollInterval - started.duration(to: .now)
            if remaining > .zero {
                try? await Task.sleep(for: remaining)
            }
        }
    }

    private func poll() async {
        let credentials = PerformerCredentials.current()
        do {
            let peek = try await ForcePeekService.fetch(
                id: credentials.identifier,
                token: credentials.writeToken
            )
            if let fresh = Self.freshValue(peek) {
                state = .value(fresh)
            } else {
                // Nothing reported, or only a value too old to trust.
                state = .waiting
            }
        } catch ForceConfigService.ServiceError.unauthorized {
            state = .notAuthorized
        } catch {
            // Transient: leave the last state in place rather than blanking it.
            debugLog("👁️ Peek read failed: \(error)")
        }
    }
}
