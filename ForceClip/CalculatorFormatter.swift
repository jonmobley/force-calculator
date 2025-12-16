import Foundation

struct CalculatorFormatter {
    static func formatResult(_ result: Double) -> String {
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
            // For decimal numbers, show appropriate decimal places
            formatter.maximumFractionDigits = 10
            formatter.minimumFractionDigits = 0
            formattedString = formatter.string(from: NSNumber(value: result)) ?? String(result)
        }
        
        // Limit display to 9 characters (including commas and decimal point)
        if formattedString.count > 9 {
            // If it's too long, try without commas first
            let withoutCommas = formattedString.replacingOccurrences(of: ",", with: "")
            if withoutCommas.count <= 9 {
                return withoutCommas
            } else {
                // If still too long, truncate to 9 characters
                return String(withoutCommas.prefix(9))
            }
        }
        
        return formattedString
    }
}
