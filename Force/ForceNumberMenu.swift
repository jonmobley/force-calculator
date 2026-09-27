import SwiftUI
import ForceShared

/// The Force Number row: shows the live number and opens a menu of saved ones.
///
/// Picking an entry makes it the force number straight away, which publishes it like any
/// other edit, so tags and QR codes already in circulation switch with it.
struct ForceNumberMenu: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @EnvironmentObject private var saved: SavedForceNumbers
    let forceNumberText: String
    let tint: Color
    /// Opens the editor for a number that is not on the list yet.
    let onNewNumber: () -> Void
    /// Opens the page for renaming, reordering and deleting entries.
    let onEditList: () -> Void

    @State private var isNamingEntry = false
    @State private var draftLabel = ""

    var body: some View {
        Menu {
            savedEntries
            Section {
                Button("New Number…", systemImage: "number", action: onNewNumber)
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
            Button("Save") { saved.add(label: draftLabel, number: settings.forceNumber) }
        } message: {
            Text("A name for \(settings.forceNumber), such as Birthday.")
        }
    }

    // MARK: - Menu

    @ViewBuilder
    private var savedEntries: some View {
        if !saved.entries.isEmpty {
            Section("Saved Numbers") {
                ForEach(saved.entries) { entry in
                    Button {
                        settings.forceNumber = entry.number
                    } label: {
                        if entry.number == settings.forceNumber {
                            Label(entry.title, systemImage: "checkmark")
                        } else {
                            Text(entry.title)
                        }
                    }
                }
            }
        }
    }

    /// Offered only for a number the list does not have, so each entry stays unique.
    @ViewBuilder
    private var saveButton: some View {
        if !forceNumberText.isEmpty, !saved.contains(settings.forceNumber) {
            Button(saveTitle, systemImage: "plus") {
                draftLabel = ""
                isNamingEntry = true
            }
            .disabled(saved.isFull)
        }
    }

    private var saveTitle: String {
        saved.isFull
            ? "List Full (\(SavedForceNumbers.limit))"
            : "Save \(settings.forceNumber) to List…"
    }

    // MARK: - Row

    /// Absolute colours throughout this row, never `.primary` or `.tertiary`. Those are
    /// hierarchical styles, and inside a control in a Form they resolve against the row's
    /// tint rather than the label colour, which turned the whole row, title included,
    /// theme-coloured and left it reading as if every word were the value.
    private var rowLabel: some View {
        HStack {
            Text("Force Number")
                .foregroundStyle(Color.primary)
            Spacer()
            if let entry = activeEntry, entry.hasName {
                Text(entry.label)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            Text(forceNumberText.isEmpty ? "Not set" : forceNumberText)
                .foregroundStyle(forceNumberText.isEmpty ? Color.secondary : tint)
            Image(systemName: "chevron.up.chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
        }
        .contentShape(Rectangle())
    }

    private var activeEntry: SavedForceNumber? {
        saved.entries.first { $0.number == settings.forceNumber }
    }
}
