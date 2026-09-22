import Foundation

/// Apple App Clip invocation URL for Force. There is no custom domain.
public struct AppClipQuery: Equatable {
    /// Signed clip bundle id. This is the `p` value.
    public static let clipBundleIdentifier = "com.mobleypro.mobley.Force.Clip"
    /// Default Apple invocation. Do not replace this with a custom host.
    public static let invocation = URL(string: "https://appclip.apple.com/id")!

    public var forceNumber: Int
    public var activationCount: Int
    public var magicTrickMode: MagicTrickMode
    public var dateTimeFormat: DateTimeFormat
    public var buttonTheme: ButtonTheme
    public var plusPerfectEnabled: Bool
    public var startWithScreenshot: Bool

    public init(settings: CalculatorSettings) {
        forceNumber = settings.forceNumber
        activationCount = settings.activationCount
        magicTrickMode = settings.magicTrickMode
        dateTimeFormat = settings.dateTimeFormat
        buttonTheme = settings.buttonTheme
        plusPerfectEnabled = settings.plusPerfectEnabled
        startWithScreenshot = settings.startWithScreenshot
    }

    // MARK: - URL

    /// Builds `https://appclip.apple.com/id` with `p`, `fn`, `ac`, `mt`, `dt`, `bt`, `pp`, and `sws`.
    public func url() -> URL {
        var components = URLComponents(url: Self.invocation, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "p", value: Self.clipBundleIdentifier),
            URLQueryItem(name: "fn", value: String(forceNumber)),
            URLQueryItem(name: "ac", value: String(activationCount)),
            URLQueryItem(name: "mt", value: magicTrickMode.rawValue),
            URLQueryItem(name: "dt", value: dateTimeFormat.rawValue),
            URLQueryItem(name: "bt", value: buttonTheme.rawValue),
            URLQueryItem(name: "pp", value: String(plusPerfectEnabled)),
            URLQueryItem(name: "sws", value: String(startWithScreenshot))
        ]
        return components.url!
    }

    /// Reads the `p` query item.
    public static func bundleIdentifier(in url: URL) -> String? {
        queryItems(in: url)?.first { $0.name == "p" }?.value
    }

    /// Copies query items that are present onto `settings` for this clip session.
    /// Does not write the app-group record.
    public static func apply(_ url: URL, to settings: CalculatorSettings) {
        guard let items = queryItems(in: url) else { return }
        applyForceNumber(items, to: settings)
        applyActivationCount(items, to: settings)
        applyMode(items, to: settings)
        applyFormat(items, to: settings)
        applyTheme(items, to: settings)
        applyFlags(items, to: settings)
    }

    // MARK: - Decode

    private static func queryItems(in url: URL) -> [URLQueryItem]? {
        URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems
    }

    private static func value(_ name: String, in items: [URLQueryItem]) -> String? {
        items.first { $0.name == name }?.value
    }

    private static func applyForceNumber(_ items: [URLQueryItem], to settings: CalculatorSettings) {
        if let raw = value("fn", in: items), let number = Int(raw) {
            settings.forceNumber = number
        }
    }

    private static func applyActivationCount(_ items: [URLQueryItem], to settings: CalculatorSettings) {
        if let raw = value("ac", in: items), let count = Int(raw) {
            settings.activationCount = count
        }
    }

    private static func applyMode(_ items: [URLQueryItem], to settings: CalculatorSettings) {
        if let raw = value("mt", in: items), let mode = MagicTrickMode(rawValue: raw) {
            settings.magicTrickMode = mode
        }
    }

    private static func applyFormat(_ items: [URLQueryItem], to settings: CalculatorSettings) {
        if let raw = value("dt", in: items), let format = DateTimeFormat(rawValue: raw) {
            settings.dateTimeFormat = format
        }
    }

    private static func applyTheme(_ items: [URLQueryItem], to settings: CalculatorSettings) {
        if let raw = value("bt", in: items), let theme = ButtonTheme(rawValue: raw) {
            settings.buttonTheme = theme
        }
    }

    private static func applyFlags(_ items: [URLQueryItem], to settings: CalculatorSettings) {
        if let raw = value("pp", in: items), let enabled = Bool(raw) {
            settings.plusPerfectEnabled = enabled
        }
        if let raw = value("sws", in: items), let enabled = Bool(raw) {
            settings.startWithScreenshot = enabled
        }
    }
}
