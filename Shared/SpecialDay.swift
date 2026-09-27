import Foundation

/// A fixed date and time the calculator reveals in Special Day mode.
///
/// Stored as wall-clock pieces rather than a `Date`. The clip runs on the spectator's
/// phone, which may sit in another time zone, and "December 25 at 7:30 PM" has to
/// read the same there as it did when the performer set it.
///
/// Deliberately carries no name. This value is published to the config service, and
/// the performer's labels for their saved days stay on the phone like saved numbers do.
public struct SpecialDay: Codable, Equatable, Hashable {
    public var year: Int
    public var month: Int
    public var day: Int
    /// 24-hour clock, 0–23.
    public var hour: Int
    public var minute: Int

    public init(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }

    /// Captures the wall-clock pieces of `date` as seen in `calendar`.
    public init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        self.init(
            year: parts.year ?? 2000,
            month: parts.month ?? 1,
            day: parts.day ?? 1,
            hour: parts.hour ?? 0,
            minute: parts.minute ?? 0
        )
    }

    // MARK: - Conversions

    /// The same wall-clock moment in `calendar`, for date pickers.
    public func date(calendar: Calendar = .current) -> Date {
        let parts = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? Date()
    }

    /// Readable date and time for settings rows, such as "Dec 25, 2026 at 7:30 PM".
    public var displayText: String {
        date().formatted(date: .abbreviated, time: .shortened)
    }

    /// `yyyyMMddHHmm`, used by the legacy sticker URL.
    public var compactValue: String {
        String(format: "%04d%02d%02d%02d%02d", year, month, day, hour, minute)
    }

    /// Reads `compactValue`. Returns nil for anything that is not twelve digits.
    public init?(compactValue raw: String) {
        guard raw.count == 12, raw.allSatisfy(\.isNumber) else { return nil }
        let digits = Array(raw)
        func number(_ range: Range<Int>) -> Int { Int(String(digits[range])) ?? 0 }
        self.init(
            year: number(0..<4),
            month: number(4..<6),
            day: number(6..<8),
            hour: number(8..<10),
            minute: number(10..<12)
        )
    }

    // MARK: - Upcoming dates

    /// The next `month`/`day` that is today or later, at the given time.
    public static func next(
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SpecialDay {
        let today = calendar.dateComponents([.year, .month, .day], from: now)
        let year = today.year ?? 2000
        let isPast = (today.month ?? 1, today.day ?? 1) > (month, day)
        return SpecialDay(year: isPast ? year + 1 : year, month: month, day: day, hour: hour, minute: minute)
    }

    /// Starting point before the performer has chosen anything: the coming Christmas.
    public static func defaultDay(now: Date = Date(), calendar: Calendar = .current) -> SpecialDay {
        next(month: 12, day: 25, now: now, calendar: calendar)
    }
}
