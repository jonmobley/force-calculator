import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: CalculatorSettings
    
    var body: some View {
        Form {
            Section(header: Text("CALCULATOR SETTINGS")) {
                NavigationLink(destination: EmptyView()) {
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                        Text("Instructions")
                        Spacer()
                    }
                }
                
                Picker("Magic Trick Mode", selection: $settings.magicTrickMode) {
                    ForEach(MagicTrickMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Picker("Button Theme", selection: $settings.buttonTheme) {
                    ForEach(ButtonTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Picker("Date/Time Format", selection: $settings.dateTimeFormat) {
                    ForEach(DateTimeFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Section(header: Text("PERFORM ON YOUR PHONE")) {
                Toggle("Open to Calculator", isOn: $settings.openToCalculator)
                
                HStack {
                    Spacer()
                    Image("screenshot")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 400)
                        .cornerRadius(10)
                    Spacer()
                }
            }
            
            Section(header: Text("QR CODE & NFC")) {
                NavigationLink(destination: QRCodeNFCView()) {
                    HStack {
                        Image(systemName: "qrcode")
                            .foregroundColor(.blue)
                        Text("QR Code & NFC")
                        Spacer()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(settings: CalculatorSettings())
} 