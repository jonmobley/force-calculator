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
        /// Nothing published yet this launch.
        case idle
        case publishing
        /// The service matches the app.
        case synced(Date)
        /// The service is behind the app. Spectators would see stale settings.
        case outOfDate(reason: String)
    }

    /// Sends one snapshot to the service. Injected so tests exercise the state machine
    /// without writing a record to the live service on every run.
    typealias Upload = @Sendable (CalculatorSettings, String, String) async throws -> Void

    /// Matches the settings autosave window so one edit produces one upload.
    private static let debounce: TimeInterval = 1.0

    @Published private(set) var state: State = .idle

    /// Whether the service has accepted this install's id at least once.
    ///
    /// The id goes on every QR code and NFC tag, and the service binds it to the first token
    /// that writes it. Handed out before that first write lands, anyone who saw the code
    /// could claim the id first and strand every tag printed with it. Remembered across
    /// launches, so a performer who is offline later can still write tags.
    @Published private(set) var hasClaimedIdentifier = false

    private let upload: Upload
    private let claimStore: UserDefaults
    private static let claimedIdentifierKey = "claimedPerformerID"

    /// - Parameter claimStore: Where the claimed id is remembered. Tests pass their own
    ///   suite so they never mark the performer's real id as claimed.
    init(
        upload: @escaping Upload = { settings, id, token in
            try await ForceConfigService.publish(settings, id: id, token: token)
        },
        claimStore: UserDefaults = .standard
    ) {
        self.upload = upload
        self.claimStore = claimStore
    }

    private var settings: CalculatorSettings?
    private var changes: AnyCancellable?
    private var inFlight: Task<Void, Never>?

    /// Held only while a failed upload is waiting for the network. A cancelled
    /// `NWPathMonitor` cannot be restarted, so each wait gets a fresh one rather than
    /// reusing a single instance; reusing one meant that after the first successful
    /// publish every later failure waited on a dead monitor and never retried.
    private var retryMonitor: NWPathMonitor?

    deinit {
        retryMonitor?.cancel()
    }

    /// Begins publishing, and uploads once immediately so the service is known to
    /// match the app rather than assumed to.
    func start(observing settings: CalculatorSettings) {
        guard changes == nil else { return }
        self.settings = settings
        let claimed = claimStore.string(forKey: Self.claimedIdentifierKey)
        hasClaimedIdentifier = claimed == PerformerCredentials.identifier

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
        let credentials = PerformerCredentials.current()

        inFlight?.cancel()
        state = .publishing
        // Snapshot now so a later edit cannot change what is already in flight.
        let snapshot = settings.snapshot()

        inFlight = Task { [weak self, upload] in
            do {
                try await upload(snapshot, credentials.identifier, credentials.writeToken)
                guard !Task.isCancelled else { return }
                self?.state = .synced(Date())
                self?.rememberClaim(of: credentials.identifier)
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

    private func rememberClaim(of identifier: String) {
        claimStore.set(identifier, forKey: Self.claimedIdentifierKey)
        hasClaimedIdentifier = true
    }

    // MARK: - Retry

    /// Publishes again as soon as a usable network path appears.
    private func retryWhenOnline() {
        guard retryMonitor == nil else { return }
        let monitor = NWPathMonitor()
        retryMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in
                guard let self, self.retryMonitor != nil else { return }
                debugLog("📶 Network back, retrying publish")
                self.publish()
            }
        }
        monitor.start(queue: DispatchQueue(label: "force.config.retry"))
    }

    private func stopRetrying() {
        guard let monitor = retryMonitor else { return }
        retryMonitor = nil
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
