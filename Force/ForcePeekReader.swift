import Combine
import Foundation
import ForceShared

/// Polls the peek service for the number the spectator is typing and publishes it
/// for the performer's UI.
///
/// Runs only while the performer is watching and live peek is on. Reading requires
/// the write token, so a missing token surfaces as its own state rather than a
/// silent blank. Transient network errors keep the last value on screen instead of
/// flickering it away between polls.
@MainActor
final class ForcePeekReader: ObservableObject {
    enum State: Equatable {
        /// Not polling.
        case idle
        /// Polling, but the spectator has not typed anything yet.
        case waiting
        /// The latest number the spectator typed.
        case value(ForcePeekService.Peek)
        /// No write token saved, so the service will not return the peek.
        case missingToken
    }

    /// Fast enough to feel live in the hand, slow enough to be gentle on battery.
    private static let pollInterval: TimeInterval = 1.5

    /// A peek older than this is treated as nothing. It guards against showing a
    /// number left over from a previous spectator: the service keeps returning the
    /// last value written, so without an age limit a stale number would sit on the
    /// readout as though the current spectator had just typed it. Comfortably
    /// longer than a spectator's pause to think, short enough that a past session
    /// does not bleed into this one. Compares the service clock against the
    /// device's, so a few seconds of skew is fine at this scale.
    static let staleAfter: TimeInterval = 30

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
            await poll()
            try? await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))
        }
    }

    private func poll() async {
        guard let token = ConfigTokenStore.load() else {
            state = .missingToken
            return
        }
        do {
            let peek = try await ForcePeekService.fetch(token: token)
            if let fresh = Self.freshValue(peek) {
                state = .value(fresh)
            } else {
                // Nothing reported, or only a value too old to trust.
                state = .waiting
            }
        } catch ForceConfigService.ServiceError.unauthorized {
            state = .missingToken
        } catch {
            // Transient: leave the last state in place rather than blanking it.
            debugLog("👁️ Peek read failed: \(error)")
        }
    }
}
