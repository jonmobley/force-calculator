import SwiftUI
import ForceShared

/// Rename, reorder and delete saved Special Days. Tap a row to rename it.
struct SavedSpecialDaysPage: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @EnvironmentObject private var saved: SavedSpecialDays

    @State private var renaming: SavedSpecialDay?
    @State private var draftLabel = ""

    var body: some View {
        List {
            Section {
                ForEach(saved.entries) { entry in
                    row(for: entry)
                }
                .onDelete(perform: saved.remove(atOffsets:))
                .onMove(perform: saved.move(fromOffsets:toOffset:))
            } footer: {
                Text(footer)
            }
        }
        .overlay {
            if saved.entries.isEmpty {
                ContentUnavailableView(
                    "No Saved Days",
                    systemImage: "calendar",
                    description: Text("Pick a Special Day, then choose Save to List.")
                )
            }
        }
        .navigationTitle("Saved Days")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .tint(settings.buttonTheme.color)
        .alert("Rename", isPresented: isRenaming, presenting: renaming) { entry in
            TextField("Name", text: $draftLabel)
            Button("Cancel", role: .cancel) {}
            Button("Save") { saved.rename(entry.id, to: draftLabel) }
        } message: { entry in
            Text("A name for \(entry.day.displayText).")
        }
    }

    // MARK: - Rows

    private func row(for entry: SavedSpecialDay) -> some View {
        Button {
            draftLabel = entry.hasName ? entry.label : ""
            renaming = entry
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.label)
                        .foregroundStyle(Color.primary)
                    if entry.hasName {
                        Text(entry.day.displayText)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                }
                Spacer()
                if entry.day == settings.specialDay {
                    Image(systemName: "checkmark")
                        .foregroundStyle(settings.buttonTheme.color)
                        .accessibilityLabel("In use")
                }
            }
            .contentShape(Rectangle())
        }
    }

    private var footer: String {
        "\(saved.entries.count) of \(SavedSpecialDays.limit). Saved days stay on this "
            + "phone; only the one in use is sent to spectators' App Clips."
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }
}
