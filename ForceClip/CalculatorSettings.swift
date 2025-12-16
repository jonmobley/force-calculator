import Foundation
import SwiftUI
import Combine

enum MagicTrickMode: String, CaseIterable, Codable {
    case forceNumber = "Force Number"
    case exactDateTime = "Date and Time"
}

enum DateTimeFormat: String, CaseIterable, Codable {
    case mmDDYY = "MMDDYYXXXX"
    case ddMMYY = "DDMMYYXXXX"
    case xxDDMMYY = "XXXXDDMMYY"
}

enum ButtonTheme: String, CaseIterable, Codable {
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
}

// Unified CalculatorSettings that works for both main app and app clip
@available(iOS 13.0, *)
class CalculatorSettings: ObservableObject, Codable {
    // Published properties for the main app
    @Published var theme: String = "dark"
    @Published var forceNumber: Int = 4556325
    @Published var activationCount: Int = 3
    @Published var currentCount: Int = 0
    @Published var magicTrickMode: MagicTrickMode = .forceNumber
    @Published var buttonTheme: ButtonTheme = .blue
    @Published var openToCalculator: Bool = false
    @Published var dateTimeFormat: DateTimeFormat = .mmDDYY
    @Published var plusPerfectEnabled: Bool = false
    @Published var startWithScreenshot: Bool = false
    
    // Constants
    static let appGroup = "group.com.mobleypro.mobley.Force"
    static let userDefaultsKey = "calculatorSettings"
    
    // CodingKeys to ensure proper encoding/decoding
    enum CodingKeys: String, CodingKey {
        case theme, forceNumber, activationCount, currentCount, magicTrickMode
        case buttonTheme, openToCalculator, dateTimeFormat, plusPerfectEnabled, startWithScreenshot
    }
    
    // Default initializer
    init() {}
    
    // Decoder initializer
    required init(from decoder: Decoder) throws {
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
    func encode(to encoder: Encoder) throws {
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
    func loadSettings() {
        if let data = UserDefaults(suiteName: Self.appGroup)?.data(forKey: Self.userDefaultsKey),
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
            self.startWithScreenshot = settings.startWithScreenshot
        }
    }
    
    // Save settings to UserDefaults
    func saveSettings() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.userDefaultsKey)
        }
    }
    
    // Helper function to generate date/time number
    func getCurrentDateTimeNumber() -> Int {
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
class SettingsManager {
    static let shared = SettingsManager()
    private let userDefaults: UserDefaults
    
    private init() {
        // Try app group first, fallback to standard UserDefaults if it fails
        if let groupDefaults = UserDefaults(suiteName: CalculatorSettings.appGroup) {
            userDefaults = groupDefaults
        } else {
            userDefaults = UserDefaults.standard
        }
    }
    
    func saveSettings(_ settings: CalculatorSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: CalculatorSettings.userDefaultsKey)
        }
    }
    
    func loadSettings() -> CalculatorSettings {
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
        }
        
        return settings
    }
}

