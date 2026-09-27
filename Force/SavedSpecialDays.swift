import Foundation
import ForceShared

/// One Special Day the performer has kept for later, with a name to find it by.
struct SavedSpecialDay: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    let day: SpecialDay

    /// Whether the performer gave it a name, rather than leaving it to read as the date.
    var hasName: Bool { label != day.displayText }
}

/// A holiday offered in the Special Day menu without being saved first.
struct SpecialDayHoliday: Identifiable, Equatable {
    let name: String
    let day: SpecialDay

    var id: String { name }

    /// Each dated to its next occurrence, so a pick never lands in the past.
    static func upcoming(now: Date = Date(), calendar: Calendar = .current) -> [SpecialDayHoliday] {
        let holidays: [(name: String, month: Int, day: Int, hour: Int, minute: Int)] = [
            ("New Year's Day", 1, 1, 0, 0),
            ("Valentine's Day", 2, 14, 0, 0),
            ("Pi Day", 3, 14, 13, 59),
            ("Halloween", 10, 31, 0, 0),
            ("Christmas", 12, 25, 0, 0),
            ("New Year's Eve", 12, 31, 23, 59)
        ]
        return holidays.map { holiday in
            SpecialDayHoliday(
                name: holiday.name,
                day: .next(
                    month: holiday.month,
                    day: holiday.day,
                    hour: holiday.hour,
                    minute: holiday.minute,
                    now: now,
                    calendar: calendar
                )
            )
        }
    }
}

/// The performer's saved Special Days, offered in a menu on the home screen.
///
/// Kept in this app's own defaults, apart from `CalculatorSettings`, for the same reason
/// as `SavedForceNumbers`: settings are published whole to the config service, and the
/// list is the performer's private repertoire. Only the day picked from it is published.
@MainActor
final class SavedSpecialDays: ObservableObject {
    /// Matches the saved numbers list, past which a menu stops being quick to read.
    static let limit = SavedForceNumbers.limit

    @Published private(set) var entries: [SavedSpecialDay] = []

    private let store: UserDefaults
    private static let entriesKey = "savedSpecialDays"

    // MARK: - Setup

    /// - Parameter store: Where the list lives. Tests pass their own suite.
    init(store: UserDefaults = .standard) {
        self.store = store
        if let data = store.data(forKey: Self.entriesKey),
           let saved = try? JSONDecoder().decode([SavedSpecialDay].self, from: data) {
            entries = saved
        }
    }

    // MARK: - Queries

    var isFull: Bool { entries.count >= Self.limit }

    func contains(_ day: SpecialDay) -> Bool {
        entries.contains { $0.day == day }
    }

    func entry(for day: SpecialDay) -> SavedSpecialDay? {
        entries.first { $0.day == day }
    }

    // MARK: - Editing

    /// Adds an entry. Returns false when the list is full or already has this day, so
    /// picking an entry is never ambiguous about which one is live.
    @discardableResult
    func add(label: String, day: SpecialDay) -> Bool {
        guard !isFull, !contains(day) else { return false }
        entries.append(SavedSpecialDay(id: UUID(), label: Self.cleaned(label, day), day: day))
        save()
        return true
    }

    func rename(_ id: SavedSpecialDay.ID, to label: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].label = Self.cleaned(label, entries[index].day)
        save()
    }

    func remove(atOffsets offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        entries.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Storage

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        store.set(data, forKey: Self.entriesKey)
    }

    /// A blank name falls back to the date itself, so every entry has something to read.
    private static func cleaned(_ label: String, _ day: SpecialDay) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? day.displayText : String(trimmed.prefix(40))
    }
}
