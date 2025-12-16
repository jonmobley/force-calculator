import Foundation
import SwiftUI
import Combine

public enum MagicTrickMode: String, CaseIterable, Codable {
    case forceNumber = "Force Number"
    case exactDateTime = "Date and Time"
}

public enum DateTimeFormat: String, CaseIterable, Codable {
    case mmDDYY = "MMDDYYXXXX"
    case ddMMYY = "DDMMYYXXXX"
    case xxDDMMYY = "XXXXDDMMYY"
}

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
    
    // Cached colors to optimize performance
    var color: Color {
        switch self {
        case .blue: return CachedColors.blue
        case .green: return CachedColors.green
        case .orange: return CachedColors.orange
        case .pink: return CachedColors.pink
        case .purple: return CachedColors.purple
        }
    }
    
    var pressedColorValue: Color {
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

// Unified CalculatorSettings that works for both main app and app clip
@available(iOS 13.0, *)
public class CalculatorSettings: ObservableObject, Codable {
    // Published properties for the main app
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
    
    // Constants
    static let appGroup = "group.com.mobleypro.mobley.Force"
    static let userDefaultsKey = "calculatorSettings"
    
    // CodingKeys to ensure proper encoding/decoding
    enum CodingKeys: String, CodingKey {
        case theme, forceNumber, activationCount, currentCount, magicTrickMode
        case buttonTheme, openToCalculator, dateTimeFormat, plusPerfectEnabled, startWithScreenshot
    }
    
    // Default initializer
    public init() {}
    
    // Decoder initializer
    required public init(from decoder: Decoder) throws {
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
    
    // Encoder method
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
    
    // Load settings from UserDefaults
    public func loadSettings() {
        debugLog("💾 CalculatorSettings: Attempting to load settings from app group: \(Self.appGroup)")
        // Use safe access method to avoid CFPrefsPlistSource errors
        let defaults = Self.safeUserDefaults()
        if let data = defaults.data(forKey: Self.userDefaultsKey),
           let settings = try? JSONDecoder().decode(CalculatorSettings.self, from: data) {
            self.theme = settings.theme
            self.forceNumber = settings.forceNumber
            self.activationCount = settings.activationCount
            self.currentCount = settings.currentCount
            self.magicTrickMode = settings.magicTrickMode
            self.buttonTheme = settings.buttonTheme
            self.openToCalculator = settings.openToCalculator
            self.dateTimeFormat = settings.dateTimeFormat
            self.plusPerfectEnabled = settings.plusPerfectEnabled
            debugLog("✅ CalculatorSettings: Settings loaded successfully")
            debugLog("   - forceNumber: \(self.forceNumber)")
            debugLog("   - magicTrickMode: \(self.magicTrickMode)")
            debugLog("   - buttonTheme: \(self.buttonTheme)")
            debugLog("   - openToCalculator: \(self.openToCalculator)")
            debugLog("   - plusPerfectEnabled: \(self.plusPerfectEnabled)")
        } else {
            debugLog("ℹ️ CalculatorSettings: No saved settings found, using defaults")
        }
    }
    
    // Save settings to UserDefaults
    public func saveSettings() {
        debugLog("💾 CalculatorSettings: Saving settings to app group: \(Self.appGroup)")
        // Use safe access method to avoid CFPrefsPlistSource errors
        let defaults = Self.safeUserDefaults()
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.userDefaultsKey)
            debugLog("✅ CalculatorSettings: Settings saved successfully")
            debugLog("   - forceNumber: \(self.forceNumber)")
            debugLog("   - magicTrickMode: \(self.magicTrickMode)")
            debugLog("   - buttonTheme: \(self.buttonTheme)")
            debugLog("   - openToCalculator: \(self.openToCalculator)")
            debugLog("   - plusPerfectEnabled: \(self.plusPerfectEnabled)")
        } else {
            debugLog("❌ CalculatorSettings: Failed to encode settings")
        }
    }
    
    // Helper to safely get UserDefaults, avoiding App Group errors
    private static func safeUserDefaults() -> UserDefaults {
        // Check if App Group is available without triggering errors
        guard let groupDefaults = UserDefaults(suiteName: Self.appGroup) else {
            return UserDefaults.standard
        }
        return groupDefaults
    }
    
    // Helper function to generate date/time number
    public func getCurrentDateTimeNumber() -> Int {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day, .year, .hour, .minute], from: now)
        
        let month = components.month ?? 1
        let day = components.day ?? 1
        let year = components.year ?? 2025
        let hour24 = components.hour ?? 0
        let minute = components.minute ?? 0
        
        // Convert 24-hour to 12-hour format
        let hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24)
        
        // Format: MMDDYYHHMM but remove leading zeros for single digits (except minutes)
        let monthStr = String(month) // No leading zeros for single-digit months
        let dayStr = String(day) // No leading zeros for single-digit days
        let yearStr = String(year % 100) // Convert to 2-digit year
        let hourStr = String(hour12) // No leading zeros for single-digit hours
        let minuteStr = String(format: "%02d", minute) // Always use 2 digits for minutes
        
        let dateTimeString = "\(monthStr)\(dayStr)\(yearStr)\(hourStr)\(minuteStr)"
        return Int(dateTimeString) ?? 7
    }
}

// SettingsManager for accessing the shared settings
public class SettingsManager {
    public static let shared = SettingsManager()
    private let userDefaults: UserDefaults
    
    private init() {
        // Safely try to access app group, fallback to standard UserDefaults
        // This avoids the CFPrefsPlistSource error by not forcing App Group access
        userDefaults = Self.safeUserDefaults()
    }
    
    // Helper to safely get UserDefaults, avoiding App Group errors
    private static func safeUserDefaults() -> UserDefaults {
        // Check if App Group is available without triggering errors
        guard let groupDefaults = UserDefaults(suiteName: CalculatorSettings.appGroup) else {
            debugLog("⚠️ App group not available, using standard UserDefaults")
            return UserDefaults.standard
        }
        
        // Verify we can actually use it by checking if it's accessible
        // Don't read/write during init to avoid blocking
        return groupDefaults
    }
    
    public func saveSettings(_ settings: CalculatorSettings) {
        debugLog("💾 SettingsManager: Saving settings")
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: CalculatorSettings.userDefaultsKey)
            debugLog("✅ SettingsManager: Settings saved successfully")
        } else {
            debugLog("❌ SettingsManager: Failed to encode settings")
        }
    }
    
    public func loadSettings() -> CalculatorSettings {
        debugLog("💾 SettingsManager: Loading settings")
        let settings = CalculatorSettings()
        
        if let data = userDefaults.data(forKey: CalculatorSettings.userDefaultsKey),
           let decodedSettings = try? JSONDecoder().decode(CalculatorSettings.self, from: data) {
            settings.theme = decodedSettings.theme
            settings.forceNumber = decodedSettings.forceNumber
            settings.activationCount = decodedSettings.activationCount
            settings.currentCount = decodedSettings.currentCount
            settings.magicTrickMode = decodedSettings.magicTrickMode
            settings.buttonTheme = decodedSettings.buttonTheme
            settings.openToCalculator = decodedSettings.openToCalculator
            settings.dateTimeFormat = decodedSettings.dateTimeFormat
            settings.plusPerfectEnabled = decodedSettings.plusPerfectEnabled
            debugLog("✅ SettingsManager: Settings loaded successfully")
        } else {
            debugLog("ℹ️ SettingsManager: No saved settings found, using defaults")
        }
        
        return settings
    }
}
