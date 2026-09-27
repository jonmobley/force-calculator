import SwiftUI
import ForceShared

/// Trick mode, the forced value, and the reveal: Perfect Plus or an equals-press count.
///
/// The two reveals are alternatives, so this section lives on the performer home
/// rather than behind its own page.
struct ForceTrickSection: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @Binding var forceNumberText: String
    /// Opens the saved-numbers page, which the enclosing stack owns: a destination
    /// declared inside a Form row is ignored.
    let onEditSavedNumbers: () -> Void
    @State private var isEditingForceNumber = false

    private var themeColor: Color { settings.buttonTheme.color }

    var body: some View {
        Section {
            modePicker
            trickValue
            perfectPlusToggle
            perfectPlusHapticsToggle
            activationPicker
        }
    }

    private var modePicker: some View {
        Picker("Magic Trick Mode", selection: $settings.magicTrickMode) {
            ForEach(MagicTrickMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.menu)
        .tint(themeColor)
    }

    @ViewBuilder
    private var trickValue: some View {
        if settings.magicTrickMode == .forceNumber {
            forceNumberField
        } else {
            dateFormatPicker
        }
    }

    private var forceNumberField: some View {
        ForceNumberMenu(
            forceNumberText: forceNumberText,
            tint: themeColor,
            onNewNumber: { isEditingForceNumber = true },
            onEditList: onEditSavedNumbers
        )
        .sheet(isPresented: $isEditingForceNumber) {
            ForceNumberEditor(
                currentText: forceNumberText,
                tint: themeColor,
                onCommit: updateForceNumber
            )
        }
    }

    private var dateFormatPicker: some View {
        Picker("Date and Time Format", selection: $settings.dateTimeFormat) {
            Text("MMDDYYXXXX").tag(DateTimeFormat.mmDDYY)
            Text("DDMMYYXXXX").tag(DateTimeFormat.ddMMYY)
            Text("XXXXDDMMYY").tag(DateTimeFormat.xxDDMMYY)
        }
        .pickerStyle(.menu)
        .tint(themeColor)
    }

    private var activationPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Activation Count", selection: $settings.activationCount) {
                ForEach(CalculatorSettings.activationCountRange, id: \.self) { count in
                    Text(count == 1 ? "1 (Immediate Force)" : "\(count) calculations").tag(count)
                }
            }
            .pickerStyle(.menu)
            .tint(themeColor)
            Text(activationCaption)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .disabled(settings.perfectPlusEnabled)
    }

    /// The count is the reveal only while Perfect Plus is off. The stored count stays,
    /// so turning Perfect Plus off puts the same number of presses back.
    private var activationCaption: String {
        if settings.perfectPlusEnabled {
            return "Perfect Plus reveals the number instead"
        }
        return ForceActivationCopy.ordinalText(for: settings.activationCount)
    }

    private var perfectPlusToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Perfect Plus", isOn: $settings.perfectPlusEnabled)
            Text("Press +, then turn the phone over. The number lands a second after the "
                + "last touch, so it is already there when the phone comes back. Without the "
                + "turn, + adds normally.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Only worth showing once the trick it belongs to is on.
    @ViewBuilder
    private var perfectPlusHapticsToggle: some View {
        if settings.perfectPlusEnabled {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Perfect Plus Vibration", isOn: $settings.perfectPlusHapticsEnabled)
                Text("Buzzes when the turn arms the trick and again when the number is ready. "
                    + "Turn it off when the spectator is the one holding the phone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func updateForceNumber(_ newValue: String) {
        guard let number = Int(newValue.filter(\.isNumber)) else { return }
        forceNumberText = String(number)
        settings.forceNumber = number
    }
}

/// Operator-key color.
struct ForceAppearancePage: View {
    @EnvironmentObject private var settings: CalculatorSettings

    var body: some View {
        Form {
            Section {
                Picker("Button Theme", selection: $settings.buttonTheme) {
                    ForEach(ButtonTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.menu)
                .tint(settings.buttonTheme.color)
            }
        }
        .navigationTitle("Button Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum ForceActivationCopy {
    static func ordinalText(for count: Int) -> String {
        "Force appears on the \(ordinal(count)) equals press"
    }

    private static func ordinal(_ number: Int) -> String {
        switch number {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(number)th"
        }
    }
}
