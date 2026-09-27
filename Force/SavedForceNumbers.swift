import Foundation
import ForceShared

/// One force number the performer has kept for later, with a name to find it by.
struct SavedForceNumber: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String
    let number: Int

    /// Whether the performer gave it a name, rather than leaving it to read as the number.
    var hasName: Bool { label != String(number) }

    /// How the entry reads in the menu.
    var title: String { hasName ? "\(label) – \(number)" : label }
}

/// The performer's saved force numbers, offered in a menu on the home screen.
///
/// Kept in this app's own defaults, apart from `CalculatorSettings`: settings are published
/// whole to the config service, where anyone with the id can read them, and the list is
/// the performer's private repertoire. Only the number picked from it is ever published.
@MainActor
final class SavedForceNumbers: ObservableObject {
    /// Past this a menu stops being quick to read mid-show.
    static let limit = 10

    @Published private(set) var entries: [SavedForceNumber] = []

    private let store: UserDefaults
    private static let entriesKey = "savedForceNumbers"
    private static let seededKey = "savedForceNumbersSeeded"

    // MARK: - Setup

    /// - Parameter store: Where the list lives. Tests pass their own suite.
    init(store: UserDefaults = .standard) {
        self.store = store
        if let data = store.data(forKey: Self.entriesKey),
           let saved = try? JSONDecoder().decode([SavedForceNumber].self, from: data) {
            entries = saved
        }
    }

    /// Starts the list with the number already in use, once, so the menu is not empty the
    /// first time. Later launches leave the list alone, even when the performer has
    /// deleted every entry.
    func seedIfNeeded(with number: Int) {
        guard !store.bool(forKey: Self.seededKey) else { return }
        store.set(true, forKey: Self.seededKey)
        if entries.isEmpty {
            add(label: "My Number", number: number)
        }
    }

    // MARK: - Queries

    var isFull: Bool { entries.count >= Self.limit }

    func contains(_ number: Int) -> Bool {
        entries.contains { $0.number == number }
    }

    // MARK: - Editing

    /// Adds an entry. Returns false when the list is full or already has this number, so
    /// picking an entry is never ambiguous about which one is live.
    @discardableResult
    func add(label: String, number: Int) -> Bool {
        let number = CalculatorSettings.clampedForceNumber(number)
        guard !isFull, !contains(number) else { return false }
        let entry = SavedForceNumber(id: UUID(), label: Self.cleaned(label, number), number: number)
        entries.append(entry)
        save()
        return true
    }

    func rename(_ id: SavedForceNumber.ID, to label: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].label = Self.cleaned(label, entries[index].number)
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

    /// A blank name falls back to the number itself, so every entry has something to read.
    private static func cleaned(_ label: String, _ number: Int) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(number) : String(trimmed.prefix(40))
    }
}
