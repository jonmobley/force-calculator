import Foundation

struct CalculatorFormatter {
    // Format display string with commas (for typing)
    static func formatDisplay(_ displayString: String) -> String {
        // Handle "0" or empty
        if displayString == "0" || displayString.isEmpty {
            return "0"
        }
        
        // Remove existing commas and parse
        let cleaned = displayString.replacingOccurrences(of: ",", with: "")
        
        // Check for negative sign
        let isNegative = cleaned.hasPrefix("-")
        let unsignedCleaned = isNegative ? String(cleaned.dropFirst()) : cleaned
        
        // Check if it's a decimal number
        if unsignedCleaned.contains(".") {
            let parts = unsignedCleaned.split(separator: ".")
            guard parts.count == 2 else { return displayString }
            
            let integerPart = String(parts[0])
            let decimalPart = String(parts[1])
            
            // Format integer part with commas
            if let intValue = Int(integerPart) {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.groupingSeparator = ","
                formatter.usesGroupingSeparator = true
                formatter.maximumFractionDigits = 0
                
                let formattedInt = formatter.string(from: NSNumber(value: intValue)) ?? integerPart
                let sign = isNegative ? "-" : ""
                return "\(sign)\(formattedInt).\(decimalPart)"
            }
        } else {
            // Whole number - format with commas
            if let intValue = Int(unsignedCleaned) {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.groupingSeparator = ","
                formatter.usesGroupingSeparator = true
                formatter.maximumFractionDigits = 0
                
                let formatted = formatter.string(from: NSNumber(value: intValue)) ?? unsignedCleaned
                let sign = isNegative ? "-" : ""
                return "\(sign)\(formatted)"
            }
        }
        
        return displayString
    }
    
    // Parse display string to Double (removing commas)
    static func parseDisplay(_ displayString: String) -> Double {
        let cleaned = displayString.replacingOccurrences(of: ",", with: "")
        return Double(cleaned) ?? 0
    }
    
    static func formatResult(_ result: Double) -> String {
        // Handle special values
        if result.isNaN {
            return "Error"
        }
        if result.isInfinite {
            return result < 0 ? "-∞" : "∞"
        }
        
        // Use scientific notation for very large or very small numbers
        let absResult = abs(result)
        if absResult > 999999999 || (absResult < 0.000001 && absResult > 0) {
            let scientificFormatter = NumberFormatter()
            scientificFormatter.numberStyle = .scientific
            scientificFormatter.exponentSymbol = "e"
            scientificFormatter.maximumFractionDigits = 3
            return scientificFormatter.string(from: NSNumber(value: result)) ?? String(result)
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        
        var formattedString: String
        
        if result.truncatingRemainder(dividingBy: 1) == 0 {
            // For whole numbers, don't show decimal places
            formatter.maximumFractionDigits = 0
            formattedString = formatter.string(from: NSNumber(value: result)) ?? String(format: "%.0f", result)
        } else {
            // For decimal numbers, limit decimal places based on available space
            // The larger the integer part, the fewer decimal places we can show
            let integerPartString = String(Int(abs(result)))
            let maxDecimalPlaces = max(9 - integerPartString.count - 1, 1) // -1 for decimal point
            
            formatter.maximumFractionDigits = maxDecimalPlaces
            formatter.minimumFractionDigits = 0
            formattedString = formatter.string(from: NSNumber(value: result)) ?? String(result)
        }
        
        // If still too long (including commas), try to fit it
        // Count digits only (excluding commas and decimal point)
        let digitCount = formattedString.filter { $0.isNumber }.count
        if digitCount > 9 {
            // Too many digits - use scientific notation
            let scientificFormatter = NumberFormatter()
            scientificFormatter.numberStyle = .scientific
            scientificFormatter.exponentSymbol = "e"
            scientificFormatter.maximumFractionDigits = 3
            return scientificFormatter.string(from: NSNumber(value: result)) ?? String(result)
        }
        
        return formattedString
    }
}
