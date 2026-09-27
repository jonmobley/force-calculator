import SwiftUI
import ForceShared

/// Drawer for picking a Special Day that is not already in the menu.
///
/// Mirrors `ForceNumberEditor`: a sheet keeps Cancel and Done in view, and naming the
/// day for the saved list happens afterwards from the menu's Save to List.
struct SpecialDayEditor: View {
    /// Day currently stored in settings, used as the starting point.
    let current: SpecialDay
    let format: DateTimeFormat
    let tint: Color
    /// Receives the chosen day when the performer taps Done.
    let onCommit: (SpecialDay) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $draft, displayedComponents: .date)
                    DatePicker("Time", selection: $draft, displayedComponents: .hourAndMinute)
                } footer: {
                    Text("The calculator reveals \(previewNumber) with your date and time format.")
                }
            }
            .navigationTitle("Special Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarButtons }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .tint(tint)
        .onAppear { draft = current.date() }
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
                onCommit(SpecialDay(date: draft))
                dismiss()
            }
            .fontWeight(.semibold)
        }
    }

    private var previewNumber: String {
        String(DateTimeNumber.format(SpecialDay(date: draft), format: format))
    }
}

#Preview {
    Text("Settings")
        .sheet(isPresented: .constant(true)) {
            SpecialDayEditor(current: .defaultDay(), format: .mmDDYY, tint: .orange, onCommit: { _ in })
        }
}
