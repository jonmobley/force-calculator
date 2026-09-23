import Foundation

/// Display parsing and grouping for the host and the App Clip.
public struct CalculatorFormatter {
    /// Widest number the readout will spell out before falling back to scientific notation.
    ///
    /// Stock iOS stops at nine, and typing is still capped there, but a forced value has to
    /// be able to reach ten: Date and Time mode builds `MMDDYY` plus a four-digit time, which
    /// runs to ten digits from October onwards and on any day past the ninth. At nine those
    /// reveals came out as `1.122e9` and the trick died on screen. Ten digits still read as a
    /// calculator result, so the ceiling moves rather than the effect.
    public static let maxDisplayDigits = 10
    /// Inserts grouping separators while the spectator is typing.
    public static func formatDisplay(_ displayString: String) -> String {
        if displayString == "0" || displayString.isEmpty {
            return "0"
        }
        let cleaned = displayString.replacingOccurrences(of: ",", with: "")
        let isNegative = cleaned.hasPrefix("-")
        let unsigned = isNegative ? String(cleaned.dropFirst()) : cleaned
        if unsigned.contains(".") {
            return formatDecimal(unsigned, isNegative: isNegative, fallback: displayString)
        }
        return formatWhole(unsigned, isNegative: isNegative, fallback: displayString)
    }

    /// Parses a display string, ignoring grouping separators.
    public static func parseDisplay(_ displayString: String) -> Double {
        let cleaned = displayString.replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }

    /// Formats a calculation result for the display.
    public static func formatResult(_ result: Double) -> String {
        if result.isNaN { return "Error" }
        if result.isInfinite { return result < 0 ? "-∞" : "∞" }
        let magnitude = abs(result)
        if magnitude > largestWholeDisplayable || (magnitude < 0.000_001 && magnitude > 0) {
            return scientific(result)
        }
        let formatted = grouped(result)
        let digitCount = formatted.filter { $0.isNumber }.count
        return digitCount > maxDisplayDigits ? scientific(result) : formatted
    }

    /// Largest whole number that still fits, as a value rather than a digit count.
    private static let largestWholeDisplayable = pow(10.0, Double(maxDisplayDigits)) - 1

    // MARK: - Formatting

    private static func formatDecimal(_ unsigned: String, isNegative: Bool, fallback: String) -> String {
        let parts = unsigned.split(separator: ".")
        guard parts.count == 2, let intValue = Int(parts[0]) else { return fallback }
        let formattedInt = integerFormatter.string(from: NSNumber(value: intValue)) ?? String(parts[0])
        let sign = isNegative ? "-" : ""
        return "\(sign)\(formattedInt).\(parts[1])"
    }

    private static func formatWhole(_ unsigned: String, isNegative: Bool, fallback: String) -> String {
        guard let intValue = Int(unsigned) else { return fallback }
        let formatted = integerFormatter.string(from: NSNumber(value: intValue)) ?? unsigned
        return (isNegative ? "-" : "") + formatted
    }

    private static func grouped(_ result: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        if result.truncatingRemainder(dividingBy: 1) == 0 {
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: result)) ?? String(format: "%.0f", result)
        }
        let integerDigits = String(Int(abs(result))).count
        formatter.maximumFractionDigits = max(maxDisplayDigits - integerDigits - 1, 1)
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: result)) ?? String(result)
    }

    private static func scientific(_ result: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .scientific
        formatter.exponentSymbol = "e"
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: result)) ?? String(result)
    }

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
