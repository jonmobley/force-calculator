import Combine
import Foundation
import ForceShared

/// Pushes the performer's settings to the config service so already-written NFC
/// tags and printed QR codes reflect the current setup.
@MainActor
final class ForceConfigPublisher: ObservableObject {
    /// Result of the most recent publish, surfaced in the settings screen.
    enum State: Equatable {
        case idle
        case missingToken
        case publishing
        case published(Date)
        case failed(String)
    }

    /// Matches the settings autosave window so one edit produces one upload.
    private static let debounce: TimeInterval = 1.0

    @Published private(set) var state: State = .idle

    private var cancellable: AnyCancellable?
    private var inFlight: Task<Void, Never>?

    /// Publishes on every later settings change.
    func start(observing settings: CalculatorSettings) {
        guard cancellable == nil else { return }
        state = ConfigTokenStore.load() == nil ? .missingToken : .idle
        cancellable = settings.objectWillChange
            // `objectWillChange` fires before the property is assigned, so the
            // upload has to be deferred to read the new value.
            .debounce(for: .seconds(Self.debounce), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.publish(settings)
            }
    }

    /// Uploads immediately, replacing any scheduled upload.
    func publish(_ settings: CalculatorSettings) {
        guard let token = ConfigTokenStore.load() else {
            state = .missingToken
            return
        }

        inFlight?.cancel()
        state = .publishing
        // Snapshot the values now so a later edit cannot change what is uploaded.
        let snapshot = settings.snapshot()

        inFlight = Task { [weak self] in
            do {
                try await ForceConfigService.publish(snapshot, token: token)
                guard !Task.isCancelled else { return }
                self?.state = .published(Date())
                debugLog("☁️ Published settings: forceNumber=\(snapshot.forceNumber)")
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .failed(Self.describe(error))
                debugLog("❌ Publish failed: \(error)")
            }
        }
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case ForceConfigService.ServiceError.unauthorized:
            return "Write token rejected. Check the token below."
        case ForceConfigService.ServiceError.server(let status):
            return "Server error \(status). Try again."
        case is URLError:
            return "No connection. Settings will upload on the next change."
        default:
            return error.localizedDescription
        }
    }
}
