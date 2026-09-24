import Foundation
import SwiftUI
import Combine

/// What the equals key reveals after the activation count.
public enum MagicTrickMode: String, CaseIterable, Codable {
    case forceNumber = "Force Number"
    case exactDateTime = "Date and Time"
}

/// Operator-key colors for the host and the App Clip.
public enum ButtonTheme: String, CaseIterable, Codable {
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"
    case purple = "Purple"

    var mainColor: String {
        switch self {
        case .blue: return "007AFF"
        case .green: return "34C759"
        case .orange: return "FF9500"
        case .pink: return "FF2D55"
        case .purple: return "AF52DE"
        }
    }

    var pressedColor: String {
        switch self {
        case .blue: return "4DA3FF"
        case .green: return "5CDB7F"
        case .orange: return "FCC78D"
        case .pink: return "FF7A9D"
        case .purple: return "C78AFF"
        }
    }

    /// Resting operator color for the current theme.
    public var color: Color {
        switch self {
        case .blue: return CachedColors.blue
        case .green: return CachedColors.green
        case .orange: return CachedColors.orange
        case .pink: return CachedColors.pink
        case .purple: return CachedColors.purple
        }
    }

    /// Pressed operator color for the current theme.
    public var pressedColorValue: Color {
        switch self {
        case .blue: return CachedColors.bluePressed
        case .green: return CachedColors.greenPressed
        case .orange: return CachedColors.orangePressed
        case .pink: return CachedColors.pinkPressed
        case .purple: return CachedColors.purplePressed
        }
    }

    private struct CachedColors {
        static let blue = Color(hex: "007AFF")
        static let green = Color(hex: "34C759")
        static let orange = Color(hex: "FF9500")
        static let pink = Color(hex: "FF2D55")
        static let purple = Color(hex: "AF52DE")
        static let bluePressed = Color(hex: "4DA3FF")
        static let greenPressed = Color(hex: "5CDB7F")
        static let orangePressed = Color(hex: "FCC78D")
        static let pinkPressed = Color(hex: "FF7A9D")
        static let purplePressed = Color(hex: "C78AFF")
    }
}

/// Saved calculator setup shared by the host and the App Clip through the app group.
public class CalculatorSettings: ObservableObject, Codable {
    @Published public var theme: String = "dark"
    @Published public var forceNumber: Int = 4556325
    @Published public var activationCount: Int = 3
    @Published public var currentCount: Int = 0
    @Published public var magicTrickMode: MagicTrickMode = .forceNumber
    /// Orange matches the stock iOS calculator, so an App Clip that has not yet
    /// received the performer's settings still looks right on the first frame.
    @Published public var buttonTheme: ButtonTheme = .orange
    @Published public var openToCalculator: Bool = false
    @Published public var dateTimeFormat: DateTimeFormat = .mmDDYY
    @Published public var perfectPlusEnabled: Bool = false
    /// Whether Perfect Plus buzzes when the turn arms it and when the number is staged.
    /// On by default, because the buzz is how the performer knows the phone can come back.
    /// Off suits handing the phone to the spectator for the turn, where they would feel it.
    @Published public var perfectPlusHapticsEnabled: Bool = true
    @Published public var startWithScreenshot: Bool = false
    /// When on, the App Clip reports the spectator's typed number back to the
    /// performer's app. Off by default so the calculator sends nothing unless the
    /// performer has deliberately turned live peek on.
    @Published public var livePeekEnabled: Bool = false

    public static let appGroup = "group.com.mobleypro.mobley.Force"
    public static let userDefaultsKey = "calculatorSettings"

    enum CodingKeys: String, CodingKey {
        case theme, forceNumber, activationCount, currentCount, magicTrickMode
        case buttonTheme, openToCalculator, dateTimeFormat, startWithScreenshot
        case livePeekEnabled
        // The trick was called Plus Perfect when these were written. Renaming the stored
        // keys would read as absent and quietly turn the trick off, both in the record
        // already saved on the performer's phone and in the settings the clip fetches.
        case perfectPlusEnabled = "plusPerfectEnabled"
        case perfectPlusHapticsEnabled = "plusPerfectHapticsEnabled"
    }

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decode(String.self, forKey: .theme)
        forceNumber = try container.decode(Int.self, forKey: .forceNumber)
        activationCount = try container.decode(Int.self, forKey: .activationCount)
        currentCount = try container.decode(Int.self, forKey: .currentCount)
        magicTrickMode = try container.decode(MagicTrickMode.self, forKey: .magicTrickMode)
        buttonTheme = try container.decodeIfPresent(ButtonTheme.self, forKey: .buttonTheme) ?? .orange
        openToCalculator = try container.decodeIfPresent(Bool.self, forKey: .openToCalculator) ?? false
        dateTimeFormat = try container.decodeIfPresent(DateTimeFormat.self, forKey: .dateTimeFormat) ?? .mmDDYY
        perfectPlusEnabled = try container.decodeIfPresent(Bool.self, forKey: .perfectPlusEnabled) ?? false
        perfectPlusHapticsEnabled = try container
            .decodeIfPresent(Bool.self, forKey: .perfectPlusHapticsEnabled) ?? true
        startWithScreenshot = try container.decodeIfPresent(Bool.self, forKey: .startWithScreenshot) ?? false
        livePeekEnabled = try container.decodeIfPresent(Bool.self, forKey: .livePeekEnabled) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(theme, forKey: .theme)
        try container.encode(forceNumber, forKey: .forceNumber)
        try container.encode(activationCount, forKey: .activationCount)
        try container.encode(currentCount, forKey: .currentCount)
        try container.encode(magicTrickMode, forKey: .magicTrickMode)
        try container.encode(buttonTheme, forKey: .buttonTheme)
        try container.encode(openToCalculator, forKey: .openToCalculator)
        try container.encode(dateTimeFormat, forKey: .dateTimeFormat)
        try container.encode(perfectPlusEnabled, forKey: .perfectPlusEnabled)
        try container.encode(perfectPlusHapticsEnabled, forKey: .perfectPlusHapticsEnabled)
        try container.encode(startWithScreenshot, forKey: .startWithScreenshot)
        try container.encode(livePeekEnabled, forKey: .livePeekEnabled)
    }

    // MARK: - Load and save

    /// Copies every stored field, including screenshot launch and Perfect Plus.
    public func applyStored(_ stored: CalculatorSettings) {
        isApplyingStoredValues = true
        defer { isApplyingStoredValues = false }
        theme = stored.theme
        forceNumber = stored.forceNumber
        activationCount = stored.activationCount
        currentCount = stored.currentCount
        magicTrickMode = stored.magicTrickMode
        buttonTheme = stored.buttonTheme
        openToCalculator = stored.openToCalculator
        dateTimeFormat = stored.dateTimeFormat
        perfectPlusEnabled = stored.perfectPlusEnabled
        perfectPlusHapticsEnabled = stored.perfectPlusHapticsEnabled
        startWithScreenshot = stored.startWithScreenshot
        livePeekEnabled = stored.livePeekEnabled
    }

    /// Where this object loads and saves. Nil uses the app-group suite.
    ///
    /// Tests set a private suite so a parallel run does not share the performer's
    /// settings with the host app or with each other.
    public var defaultsStore: UserDefaults?

    /// Replaces this object with the suite record, or leaves the defaults in place.
    public func loadSettings() {
        let defaults = persistedDefaults()
        guard let data = defaults.data(forKey: Self.userDefaultsKey),
              let stored = try? JSONDecoder().decode(CalculatorSettings.self, from: data) else {
            debugLog("ℹ️ CalculatorSettings: No saved settings found, using defaults")
            return
        }
        applyStored(stored)
        debugLog("✅ CalculatorSettings: loaded forceNumber=\(forceNumber) startWithScreenshot=\(startWithScreenshot)")
    }

    /// Writes this object into the app-group suite.
    public func saveSettings() {
        let defaults = persistedDefaults()
        guard let data = try? JSONEncoder().encode(self) else {
            debugLog("❌ CalculatorSettings: Failed to encode settings")
            return
        }
        defaults.set(data, forKey: Self.userDefaultsKey)
        debugLog("✅ CalculatorSettings: saved forceNumber=\(forceNumber)")
    }

    // MARK: - Autosave

    /// Coalescing window for autosaves. One edit reaches several observers, so a
    /// short delay collapses a burst of notifications into a single write.
    private static let autosaveDelay: TimeInterval = 0.25

    private var autosaveCancellable: AnyCancellable?
    private var pendingSave: DispatchWorkItem?
    private var isApplyingStoredValues = false

    /// Persists every later change automatically.
    ///
    /// Only the host calls this. The App Clip takes its values from the
    /// invocation URL and must not write them back into the shared group.
    public func beginAutosave() {
        guard autosaveCancellable == nil else { return }
        autosaveCancellable = objectWillChange.sink { [weak self] _ in
            self?.scheduleSave()
        }
    }

    /// Writes a coalesced change right away. Call this when the app loses focus.
    public func flushPendingSave() {
        guard pendingSave != nil else { return }
        pendingSave?.cancel()
        pendingSave = nil
        saveSettings()
    }

    private func scheduleSave() {
        guard !isApplyingStoredValues else { return }
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingSave = nil
            self?.saveSettings()
        }
        pendingSave = work
        // `objectWillChange` fires before the property is assigned, so the write
        // has to happen after the current run loop turn to see the new value.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autosaveDelay, execute: work)
    }

    // MARK: - Date and time

    /// Current date/time integer using `dateTimeFormat`.
    public func getCurrentDateTimeNumber(now: Date = Date(), calendar: Calendar = .current) -> Int {
        DateTimeNumber.format(now, format: dateTimeFormat, calendar: calendar)
    }

    /// The number the equals key will land on in the current mode: the stored force
    /// number, or whatever the clock reads right now in Date and Time mode. Defined once
    /// here because several places need the same answer and a third mode would otherwise
    /// have to be added to each of them.
    public var forcedNumber: Int {
        magicTrickMode == .forceNumber ? forceNumber : getCurrentDateTimeNumber()
    }

    private func persistedDefaults() -> UserDefaults {
        defaultsStore ?? Self.suiteDefaults()
    }

    private static func suiteDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }
}
