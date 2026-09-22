import Foundation

/// Digit order for the number `DateTimeNumber` builds.
public enum DateTimeFormat: String, CaseIterable, Codable {
    /// Month, day, year, then 12-hour time (`MMDDYY` + `HHMM`).
    case mmDDYY = "MMDDYYXXXX"
    /// Day, month, year, then 12-hour time (`DDMMYY` + `HHMM`).
    case ddMMYY = "DDMMYYXXXX"
    /// 12-hour time, then day, month, and year (`HHMM` + `DDMMYY`).
    case xxDDMMYY = "XXXXDDMMYY"
}

/// Builds the forced date/time integer shared by the host and the App Clip.
public enum DateTimeNumber {
    /// Formats `date` so each label piece keeps its width.
    ///
    /// `MM`, `DD`, and `YY` are two digits. `XXXX` is 12-hour `HHMM`.
    /// Hour 0 and hour 12 both format as 12. Hour 13 formats as 01.
    /// Leading zeros are kept in the digit string, then stored as `Int`.
    public static func format(
        _ date: Date,
        format: DateTimeFormat,
        calendar: Calendar = .current
    ) -> Int {
        let parts = pieces(of: date, calendar: calendar)
        let month = String(format: "%02d", parts.month)
        let day = String(format: "%02d", parts.day)
        let year = String(format: "%02d", parts.year)
        let time = String(format: "%02d%02d", parts.hour12, parts.minute)
        let raw: String
        switch format {
        case .mmDDYY:
            raw = month + day + year + time
        case .ddMMYY:
            raw = day + month + year + time
        case .xxDDMMYY:
            raw = time + day + month + year
        }
        return Int(raw) ?? 0
    }

    // MARK: - Formatting

    private struct Pieces {
        var month: Int
        var day: Int
        var year: Int
        var hour12: Int
        var minute: Int
    }

    private static func pieces(of date: Date, calendar: Calendar) -> Pieces {
        let components = calendar.dateComponents([.month, .day, .year, .hour, .minute], from: date)
        let hour24 = components.hour ?? 0
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return Pieces(
            month: components.month ?? 1,
            day: components.day ?? 1,
            year: (components.year ?? 0) % 100,
            hour12: hour12,
            minute: components.minute ?? 0
        )
    }
}
