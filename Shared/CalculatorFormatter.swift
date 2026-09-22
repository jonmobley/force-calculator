import Foundation

/// Display parsing and grouping for the host and the App Clip.
public struct CalculatorFormatter {
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

    /// Formats a calculation result for the 9-digit display.
    public static func formatResult(_ result: Double) -> String {
        if result.isNaN { return "Error" }
        if result.isInfinite { return result < 0 ? "-∞" : "∞" }
        let magnitude = abs(result)
        if magnitude > 999_999_999 || (magnitude < 0.000_001 && magnitude > 0) {
            return scientific(result)
        }
        let formatted = grouped(result)
        let digitCount = formatted.filter { $0.isNumber }.count
        return digitCount > 9 ? scientific(result) : formatted
    }

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
        formatter.maximumFractionDigits = max(9 - integerDigits - 1, 1)
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
