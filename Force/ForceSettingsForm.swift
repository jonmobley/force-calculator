import SwiftUI
import ForceShared

/// Magician controls for the force, theme, launch, and Plus Perfect.
struct ForceCalculatorSettingsSection: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @Binding var forceNumberText: String

    private var themeColor: Color { settings.buttonTheme.color }

    var body: some View {
        Section(header: Text("Calculator Settings")) {
            Toggle("Open to Calculator", isOn: $settings.openToCalculator)
            themePicker
            modePicker
            trickValue
            activationPicker
            plusPerfectToggle
            screenshotToggle
        }
    }

    private var themePicker: some View {
        Picker("Button Theme", selection: $settings.buttonTheme) {
            ForEach(ButtonTheme.allCases, id: \.self) { theme in
                Text(theme.rawValue).tag(theme)
            }
        }
        .pickerStyle(.menu)
        .tint(themeColor)
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
        HStack {
            Text("Force Number")
            Spacer()
            TextField("Enter number", text: $forceNumberText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: forceNumberText) { _, newValue in
                    updateForceNumber(newValue)
                }
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
                ForEach(1...10, id: \.self) { count in
                    Text(count == 1 ? "1 (Immediate Force)" : "\(count) calculations").tag(count)
                }
            }
            .pickerStyle(.menu)
            .tint(themeColor)
            Text(ForceActivationCopy.ordinalText(for: settings.activationCount))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var plusPerfectToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Plus Perfect", isOn: $settings.plusPerfectEnabled)
            Text("Upside-down + arms the trick. Upright + adds normally.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var screenshotToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Start with Screenshot", isOn: $settings.startWithScreenshot)
            Text("App starts showing screenshot, tap anywhere to open calculator")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func updateForceNumber(_ newValue: String) {
        let filtered = newValue.filter(\.isNumber)
        if filtered != newValue {
            forceNumberText = filtered
            return
        }
        guard let number = Int(filtered) else { return }
        settings.forceNumber = number
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
