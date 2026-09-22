import SwiftUI
import ForceShared

/// Drawer for editing the force number.
///
/// The number pad has no return key, so editing inline inside the settings form
/// left no obvious way to put the keyboard away. Presenting the field in a sheet
/// keeps Cancel and Done visible above the keyboard the whole time.
struct ForceNumberEditor: View {
    /// Digits currently stored in the settings form.
    let currentText: String
    let tint: Color
    /// Receives the sanitized digits when the magician taps Done.
    let onCommit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var isFieldFocused: Bool

    /// Longer values overflow the calculator readout, so cap what can be typed.
    private static let maxDigits = 12

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Force Number")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarButtons }
        }
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.visible)
        .tint(tint)
        .task { await beginEditing() }
    }

    // MARK: - Layout

    private var content: some View {
        VStack(spacing: 12) {
            numberField
            Text("The calculator reveals this number once the activation count is reached.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var numberField: some View {
        TextField("Enter number", text: $draft)
            .keyboardType(.numberPad)
            .focused($isFieldFocused)
            .font(.system(size: 36, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .onChange(of: draft) { _, newValue in
                let sanitized = Self.sanitize(newValue)
                if sanitized != newValue { draft = sanitized }
            }
            .onSubmit(commit)
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Done", action: commit)
                .fontWeight(.semibold)
                .disabled(draft.isEmpty)
        }
    }

    // MARK: - Editing

    private func beginEditing() async {
        draft = currentText
        // Focusing in the same turn the sheet appears is unreliable; wait for the
        // presentation animation to settle so the keyboard actually comes up.
        try? await Task.sleep(for: .milliseconds(350))
        isFieldFocused = true
    }

    private func commit() {
        let sanitized = Self.sanitize(draft)
        guard !sanitized.isEmpty else { return }
        onCommit(sanitized)
        dismiss()
    }

    private static func sanitize(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(maxDigits))
    }
}

#Preview {
    Text("Settings")
        .sheet(isPresented: .constant(true)) {
            ForceNumberEditor(currentText: "4556325", tint: .blue, onCommit: { _ in })
        }
}
