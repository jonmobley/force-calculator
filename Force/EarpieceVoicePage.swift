import SwiftUI
import AVFoundation
import ForceShared

/// Performer-only preferences for the voice in the headphones. Kept on this phone
/// (not synced to the App Clip), because the clip runs on the spectator's phone.
enum EarpiecePrefs {
    static let enabledKey = "earpieceEnabled"
    static let typedKey = "earpieceSpeakTyped"
    static let answersKey = "earpieceSpeakAnswers"
    static let livePeekKey = "earpieceSpeakLivePeek"
    static let digitsKey = "earpieceDigitByDigit"
    static let rateKey = "earpieceRate"
    static let twiceKey = "earpieceTwice"
    static let voiceKey = "earpieceVoice"

    private static var defaults: UserDefaults { .standard }

    static var enabled: Bool { defaults.bool(forKey: enabledKey) }

    /// Speaks a number the way the performer asked for, if the voice is on.
    @MainActor
    static func speak(number: String) {
        guard enabled else { return }
        let digitByDigit = defaults.object(forKey: digitsKey) as? Bool ?? true
        let text = digitByDigit ? EarpieceVoice.digits(number) : number.replacingOccurrences(of: ",", with: "")
        EarpieceVoice.shared.say(
            text,
            rate: defaults.object(forKey: rateKey) as? Double ?? 0.5,
            twice: defaults.bool(forKey: twiceKey),
            voiceIdentifier: defaults.string(forKey: voiceKey) ?? ""
        )
    }

    /// Called by the calculator for each number the spectator finishes.
    @MainActor
    static func handle(_ entry: SpectatorEntry) {
        switch entry {
        case .typed(let value):
            if defaults.object(forKey: typedKey) as? Bool ?? true { speak(number: value) }
        case .answer(let value):
            if defaults.bool(forKey: answersKey) { speak(number: value) }
        }
    }
}

/// Earpiece Voice page: the switch, what to say, and how it sounds.
struct EarpieceVoicePage: View {
    @ObservedObject private var voice = EarpieceVoice.shared
    @AppStorage(EarpiecePrefs.enabledKey) private var enabled = false
    @AppStorage(EarpiecePrefs.typedKey) private var speakTyped = true
    @AppStorage(EarpiecePrefs.answersKey) private var speakAnswers = false
    @AppStorage(EarpiecePrefs.livePeekKey) private var speakLivePeek = true
    @AppStorage(EarpiecePrefs.digitsKey) private var digitByDigit = true
    @AppStorage(EarpiecePrefs.rateKey) private var rate = 0.5
    @AppStorage(EarpiecePrefs.twiceKey) private var twice = false
    @AppStorage(EarpiecePrefs.voiceKey) private var voiceIdentifier = ""
    @State private var testFailed = false

    var body: some View {
        Form {
            Section {
                Toggle("Earpiece Voice", isOn: $enabled)
                headphonesRow
            } footer: {
                Text("Quietly says the spectator's numbers in your headphones while they use the calculator. "
                    + "It only speaks through headphones — with none connected it stays silent, never out loud.")
            }

            if enabled {
                Section("Say") {
                    Toggle("Numbers They Type", isOn: $speakTyped)
                    Toggle("Answers", isOn: $speakAnswers)
                    if CalculatorSettings.livePeekAvailable {
                        Toggle("Live Peek Numbers", isOn: $speakLivePeek)
                    }
                }

                Section {
                    Picker("Read Numbers", selection: $digitByDigit) {
                        Text("Digit by Digit").tag(true)
                        Text("Whole Number").tag(false)
                    }
                    VStack(alignment: .leading) {
                        Text("Speed")
                        HStack {
                            Image(systemName: "tortoise")
                                .foregroundStyle(.secondary)
                            Slider(value: $rate, in: 0.3...0.65)
                            Image(systemName: "hare")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Say It Twice", isOn: $twice)
                    Picker("Voice", selection: $voiceIdentifier) {
                        Text("Best Available").tag("")
                        ForEach(EarpieceVoice.availableVoices, id: \.identifier) { voice in
                            Text(label(for: voice)).tag(voice.identifier)
                        }
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    Text(voiceFooter)
                }

                Section {
                    Button {
                        testFailed = !EarpieceVoice.shared.say(
                            digitByDigit ? EarpieceVoice.digits("1234") : "1234",
                            rate: rate,
                            twice: twice,
                            voiceIdentifier: voiceIdentifier
                        )
                    } label: {
                        Label("Test the Voice", systemImage: "play.circle")
                    }
                } footer: {
                    if testFailed && voice.headphoneName == nil {
                        Text("Connect your headphones first — the voice never plays through the speaker.")
                    }
                }
            }
        }
        .navigationTitle("Earpiece Voice")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headphonesRow: some View {
        HStack {
            Label("Headphones", systemImage: "headphones")
            Spacer()
            Text(voice.headphoneName ?? "Not Connected")
                .foregroundStyle(.secondary)
        }
    }

    private func label(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: return "\(voice.name) (Premium)"
        case .enhanced: return "\(voice.name) (Enhanced)"
        default: return voice.name
        }
    }

    private var voiceFooter: String {
        if EarpieceVoice.hasNaturalVoice { return "Digit by digit is easiest to catch in a noisy room." }
        return "Only basic voices are installed. For a natural voice, download one in the Settings app: "
            + "Accessibility › Read & Speak › Voices."
    }
}
