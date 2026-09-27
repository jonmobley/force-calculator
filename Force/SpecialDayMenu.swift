import SwiftUI
import ForceShared

/// The Special Day row: shows the live day and opens a menu of saved days and holidays.
///
/// Mirrors `ForceNumberMenu`. Picking an entry makes it the Special Day straight away,
/// which publishes it like any other edit, so tags and QR codes switch with it.
struct SpecialDayMenu: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @EnvironmentObject private var saved: SavedSpecialDays
    let tint: Color
    /// Opens the date and time picker for a day that is not on either list.
    let onNewDay: () -> Void
    /// Opens the page for renaming, reordering and deleting entries.
    let onEditList: () -> Void

    @State private var isNamingEntry = false
    @State private var draftLabel = ""

    private let holidays = SpecialDayHoliday.upcoming()

    var body: some View {
        Menu {
            savedEntries
            holidayEntries
            Section {
                Button("New Date…", systemImage: "calendar", action: onNewDay)
                saveButton
                Button("Edit List…", systemImage: "list.bullet", action: onEditList)
                    .disabled(saved.entries.isEmpty)
            }
        } label: {
            rowLabel
        }
        .alert("Save to List", isPresented: $isNamingEntry) {
            TextField("Name", text: $draftLabel)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saved.add(label: draftLabel, day: settings.specialDay) }
        } message: {
            Text("A name for \(settings.specialDay.displayText), such as Anniversary.")
        }
    }

    // MARK: - Menu

    @ViewBuilder
    private var savedEntries: some View {
        if !saved.entries.isEmpty {
            Section("Saved Days") {
                ForEach(saved.entries) { entry in
                    choice(entry.hasName ? "\(entry.label) – \(entry.day.displayText)" : entry.label,
                           day: entry.day)
                }
            }
        }
    }

    private var holidayEntries: some View {
        Section("Holidays") {
            ForEach(holidays) { holiday in
                choice("\(holiday.name) – \(holiday.day.displayText)", day: holiday.day)
            }
        }
    }

    private func choice(_ title: String, day: SpecialDay) -> some View {
        Button {
            settings.specialDay = day
        } label: {
            if day == settings.specialDay {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    /// Offered only for a day the list does not have, so each entry stays unique.
    @ViewBuilder
    private var saveButton: some View {
        if !saved.contains(settings.specialDay) {
            Button(saved.isFull ? "List Full (\(SavedSpecialDays.limit))" : "Save to List…",
                   systemImage: "plus") {
                draftLabel = activeHoliday?.name ?? ""
                isNamingEntry = true
            }
            .disabled(saved.isFull)
        }
    }

    // MARK: - Row

    /// Absolute colours throughout, for the same reason as `ForceNumberMenu`: hierarchical
    /// styles resolve against the row's tint inside a Form control.
    private var rowLabel: some View {
        HStack {
            Text("Special Day")
                .foregroundStyle(Color.primary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let name = activeName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                Text(settings.specialDay.displayText)
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
        }
        .contentShape(Rectangle())
    }

    private var activeHoliday: SpecialDayHoliday? {
        holidays.first { $0.day == settings.specialDay }
    }

    private var activeName: String? {
        if let entry = saved.entry(for: settings.specialDay), entry.hasName { return entry.label }
        return activeHoliday?.name
    }
}
