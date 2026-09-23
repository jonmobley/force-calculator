import Foundation

/// Sends peek updates in order and retries one that the network dropped.
///
/// A number is reported bare, then again with the key that ended it, and the next
/// number must not land first. Entries therefore go out one at a time, in the order
/// they were first seen. A newer value for an entry replaces one still waiting, so a
/// retry cannot write a digit the spectator has already moved past.
public actor PeekUploader {
    /// Delivers one entry to the service.
    public typealias Send = @Sendable (
        _ value: String,
        _ entryID: String,
        _ op: String?,
        _ performerID: String
    ) async throws -> Void

    private struct Item {
        var value: String
        var op: String?
        var generation: Int
    }

    private let send: Send
    /// One delay per retry. The first attempt happens immediately.
    private let retryDelays: [Duration]
    private var order: [String] = []
    private var latest: [String: Item] = [:]
    private var generations: [String: Int] = [:]
    private var draining = false

    /// - Parameters:
    ///   - retryDelays: Pause before each retry. Empty means a failure is dropped.
    ///   - send: The upload. Tests pass one that records calls and throws on demand.
    public init(
        retryDelays: [Duration] = [.milliseconds(400)],
        send: @escaping Send
    ) {
        self.retryDelays = retryDelays
        self.send = send
    }

    /// Records the latest payload for an entry and delivers everything still queued.
    public func submit(value: String, entryID: String, op: String?, id: String) async {
        let generation = (generations[entryID] ?? 0) + 1
        generations[entryID] = generation
        if latest[entryID] == nil {
            order.append(entryID)
        }
        latest[entryID] = Item(value: value, op: op, generation: generation)
        await drain(performerID: id)
    }

    // MARK: - Delivery

    private func drain(performerID: String) async {
        guard !draining else { return }
        draining = true
        defer { draining = false }
        while let entryID = order.first {
            await sendLatest(entryID, performerID: performerID)
        }
    }

    /// Sends the current payload for one entry, then any replacement that arrived
    /// while that send was in flight. Gives up after the retries run out.
    private func sendLatest(_ entryID: String, performerID: String) async {
        var attempt = 0
        var sending: Int?
        while let item = latest[entryID] {
            if sending != item.generation {
                sending = item.generation
                attempt = 0
            }
            if await attemptSend(item, entryID: entryID, performerID: performerID) {
                guard latest[entryID]?.generation == item.generation else { continue }
                finish(entryID)
                return
            }
            guard latest[entryID]?.generation == item.generation else { continue }
            guard attempt < retryDelays.count else {
                finish(entryID)
                return
            }
            try? await Task.sleep(for: retryDelays[attempt])
            attempt += 1
        }
        finish(entryID)
    }

    /// True when the service accepted the payload.
    private func attemptSend(_ item: Item, entryID: String, performerID: String) async -> Bool {
        do {
            try await send(item.value, entryID, item.op, performerID)
            return true
        } catch {
            return false
        }
    }

    private func finish(_ entryID: String) {
        latest[entryID] = nil
        order.removeAll { $0 == entryID }
    }
}
