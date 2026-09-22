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
        case .orange: return "FF9F0A"
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
        static let orange = Color(hex: "FF9F0A")
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
    @Published public var buttonTheme: ButtonTheme = .blue
    @Published public var openToCalculator: Bool = false
    @Published public var dateTimeFormat: DateTimeFormat = .mmDDYY
    @Published public var plusPerfectEnabled: Bool = false
    @Published public var startWithScreenshot: Bool = false

    public static let appGroup = "group.com.mobleypro.mobley.Force"
    public static let userDefaultsKey = "calculatorSettings"

    enum CodingKeys: String, CodingKey {
        case theme, forceNumber, activationCount, currentCount, magicTrickMode
        case buttonTheme, openToCalculator, dateTimeFormat, plusPerfectEnabled, startWithScreenshot
    }

    public init() {}

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decode(String.self, forKey: .theme)
        forceNumber = try container.decode(Int.self, forKey: .forceNumber)
        activationCount = try container.decode(Int.self, forKey: .activationCount)
        currentCount = try container.decode(Int.self, forKey: .currentCount)
        magicTrickMode = try container.decode(MagicTrickMode.self, forKey: .magicTrickMode)
        buttonTheme = try container.decodeIfPresent(ButtonTheme.self, forKey: .buttonTheme) ?? .blue
        openToCalculator = try container.decodeIfPresent(Bool.self, forKey: .openToCalculator) ?? false
        dateTimeFormat = try container.decodeIfPresent(DateTimeFormat.self, forKey: .dateTimeFormat) ?? .mmDDYY
        plusPerfectEnabled = try container.decodeIfPresent(Bool.self, forKey: .plusPerfectEnabled) ?? false
        startWithScreenshot = try container.decodeIfPresent(Bool.self, forKey: .startWithScreenshot) ?? false
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
        try container.encode(plusPerfectEnabled, forKey: .plusPerfectEnabled)
        try container.encode(startWithScreenshot, forKey: .startWithScreenshot)
    }

    // MARK: - Load and save

    /// Copies every stored field, including screenshot launch and Plus Perfect.
    public func applyStored(_ stored: CalculatorSettings) {
        theme = stored.theme
        forceNumber = stored.forceNumber
        activationCount = stored.activationCount
        currentCount = stored.currentCount
        magicTrickMode = stored.magicTrickMode
        buttonTheme = stored.buttonTheme
        openToCalculator = stored.openToCalculator
        dateTimeFormat = stored.dateTimeFormat
        plusPerfectEnabled = stored.plusPerfectEnabled
        startWithScreenshot = stored.startWithScreenshot
    }

    /// Replaces this object with the suite record, or leaves the defaults in place.
    public func loadSettings() {
        let defaults = Self.suiteDefaults()
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
        let defaults = Self.suiteDefaults()
        guard let data = try? JSONEncoder().encode(self) else {
            debugLog("❌ CalculatorSettings: Failed to encode settings")
            return
        }
        defaults.set(data, forKey: Self.userDefaultsKey)
        debugLog("✅ CalculatorSettings: saved forceNumber=\(forceNumber)")
    }

    // MARK: - Date and time

    /// Current date/time integer using `dateTimeFormat`.
    public func getCurrentDateTimeNumber(now: Date = Date(), calendar: Calendar = .current) -> Int {
        DateTimeNumber.format(now, format: dateTimeFormat, calendar: calendar)
    }

    private static func suiteDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }
}
