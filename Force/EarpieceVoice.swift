import AVFoundation
import Combine

/// Speaks a secret into the performer's headphones.
///
/// It only ever talks when headphones (Bluetooth or wired) are the phone's audio
/// output. With nothing connected it stays silent rather than falling back to the
/// speaker, where the spectator would hear it. Music already playing is ducked
/// under the voice and comes back when it finishes.
@MainActor
final class EarpieceVoice: NSObject, ObservableObject {
    static let shared = EarpieceVoice()

    /// Name of the connected headphones ("AirPods Pro"), or nil when there are none.
    @Published private(set) var headphoneName: String?

    private let synthesizer = AVSpeechSynthesizer()
    /// Utterances still to finish; the audio is handed back once this empties.
    private var pending: Set<ObjectIdentifier> = []
    private var routeObserver: NSObjectProtocol?

    private static let headphonePorts: Set<AVAudioSession.Port> = [
        .headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE,
    ]

    override init() {
        super.init()
        synthesizer.delegate = self
        // Follow our own audio session, so the headphone check below is what decides.
        synthesizer.usesApplicationAudioSession = true
        refreshRoute()
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshRoute() }
        }
    }

    // MARK: - Voices

    /// Voices for the phone's language, best sounding first. Asking iOS is slow,
    /// so this is looked up once.
    static let availableVoices: [AVSpeechSynthesisVoice] = {
        let language = AVSpeechSynthesisVoice.currentLanguageCode()
        let prefix = String(language.prefix(2))
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            guard voice.language.hasPrefix(prefix) else { return false }
            if #available(iOS 17.0, *) { return !voice.voiceTraits.contains(.isNoveltyVoice) }
            return true
        }
        return voices.sorted {
            if ($0.language == language) != ($1.language == language) { return $0.language == language }
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            return $0.name < $1.name
        }
    }()

    /// False when only Apple's basic voices are installed; those sound robotic.
    static var hasNaturalVoice: Bool {
        availableVoices.contains { $0.quality == .enhanced || $0.quality == .premium }
    }

    private static func voice(_ identifier: String) -> AVSpeechSynthesisVoice? {
        if !identifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        return availableVoices.first
    }

    // MARK: - Speaking

    /// Says `text` in the headphones, cutting off anything still being said.
    /// Returns false, and says nothing, when no headphones are connected.
    @discardableResult
    func say(_ text: String, rate: Double = 0.5, twice: Bool = false, voiceIdentifier: String = "") -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            return false
        }
        // Checked after the session is live, because that is the route the voice would take.
        refreshRoute()
        guard headphoneName != nil else {
            if pending.isEmpty { deactivate() }
            return false
        }

        stop()
        let voice = Self.voice(voiceIdentifier)
        for pass in 0..<(twice ? 2 : 1) {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = Float(min(max(rate, 0), 1))
                * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
                + AVSpeechUtteranceMinimumSpeechRate
            utterance.preUtteranceDelay = pass == 0 ? 0 : 0.8
            pending.insert(ObjectIdentifier(utterance))
            synthesizer.speak(utterance)
        }
        return true
    }

    func stop() {
        pending.removeAll()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    /// "4,521" becomes "4, 5, 2, 1" so the voice reads one digit at a time.
    nonisolated static func digits(_ value: String) -> String {
        var words: [String] = []
        for character in value {
            if character.isNumber {
                words.append(String(character))
            } else if character == "." {
                words.append("point")
            } else if character == "-" || character == "−", words.isEmpty {
                words.append("minus")
            }
        }
        return words.joined(separator: ", ")
    }

    // MARK: - Helpers

    private func refreshRoute() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        headphoneName = outputs.first { Self.headphonePorts.contains($0.portType) }?.portName
    }

    private func finished(_ id: ObjectIdentifier) {
        guard pending.remove(id) != nil, pending.isEmpty else { return }
        deactivate()
    }

    /// Hands the audio back so ducked music returns to full volume.
    private func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension EarpieceVoice: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finished(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finished(id) }
    }
}
