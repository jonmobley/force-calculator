import Combine
import Foundation
import ForceShared
import Network

/// Keeps the config service in step with the performer's settings, so NFC
/// stickers and printed QR codes already in circulation stay correct.
///
/// A failed upload is the dangerous case: the performer would think the new force
/// number is live while spectators still receive the previous one. Failures are
/// therefore surfaced as a warning and retried as soon as the network returns.
@MainActor
final class ForceConfigPublisher: ObservableObject {
    enum State: Equatable {
        /// No token entered, so nothing is published.
        case missingToken
        case publishing
        /// The service matches the app.
        case synced(Date)
        /// The service is behind the app. Spectators would see stale settings.
        case outOfDate(reason: String)
    }

    /// Matches the settings autosave window so one edit produces one upload.
    private static let debounce: TimeInterval = 1.0

    @Published private(set) var state: State = .missingToken

    private var settings: CalculatorSettings?
    private var changes: AnyCancellable?
    private var inFlight: Task<Void, Never>?
    private let monitor = NWPathMonitor()
    private var isMonitoringForRetry = false

    deinit {
        monitor.cancel()
    }

    /// Begins publishing, and uploads once immediately so the service is known to
    /// match the app rather than assumed to.
    func start(observing settings: CalculatorSettings) {
        guard changes == nil else { return }
        self.settings = settings

        changes = settings.objectWillChange
            // `objectWillChange` fires before the property is assigned, so the
            // upload has to be deferred to read the new value.
            .debounce(for: .seconds(Self.debounce), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.publish()
            }

        publish()
    }

    /// Uploads the current settings, replacing any upload already in flight.
    func publish() {
        guard let settings else { return }
        guard let token = ConfigTokenStore.load() else {
            state = .missingToken
            return
        }

        inFlight?.cancel()
        state = .publishing
        // Snapshot now so a later edit cannot change what is already in flight.
        let snapshot = settings.snapshot()

        inFlight = Task { [weak self] in
            do {
                try await ForceConfigService.publish(snapshot, token: token)
                guard !Task.isCancelled else { return }
                self?.state = .synced(Date())
                self?.stopRetrying()
                debugLog("☁️ Published settings: forceNumber=\(snapshot.forceNumber)")
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .outOfDate(reason: Self.describe(error))
                self?.retryWhenOnline()
                debugLog("❌ Publish failed: \(error)")
            }
        }
    }

    // MARK: - Retry

    /// Publishes again as soon as a usable network path appears.
    private func retryWhenOnline() {
        guard !isMonitoringForRetry else { return }
        isMonitoringForRetry = true
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isMonitoringForRetry else { return }
                debugLog("📶 Network back, retrying publish")
                self.publish()
            }
        }
        monitor.start(queue: DispatchQueue(label: "force.config.retry"))
    }

    private func stopRetrying() {
        guard isMonitoringForRetry else { return }
        isMonitoringForRetry = false
        monitor.pathUpdateHandler = nil
        monitor.cancel()
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case ForceConfigService.ServiceError.unauthorized:
            return "Write token rejected"
        case ForceConfigService.ServiceError.server(let status):
            return "Server error \(status)"
        case is URLError:
            return "No connection"
        default:
            return error.localizedDescription
        }
    }
}
