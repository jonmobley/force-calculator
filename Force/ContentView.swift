import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var settings = CalculatorSettings()
    @State private var forceNumberText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var backgroundImage: UIImage?
    @State private var showingCalculator = false
    @State private var showQRCodeView = false
    
    // Cached theme color to avoid repeated Color(hex:) calls
    private var themeColor: Color {
        Color(hex: settings.buttonTheme.mainColor)
    }
    
    init() {
        debugLog("🟢 ContentView: Initializing")
    }
    
    var body: some View {
        let _ = debugLog("🟡 ContentView: Body is being evaluated")
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    calculatorSettingsSection
                    performOnPhoneSection
                    Section {
                        qrCodeButton
                    } header: {
                        Text("Share App Clip")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Bottom button following Apple HIG
                VStack(spacing: 0) {
                    Divider()
                    
                    Button(action: { 
                        debugLog("🔵 'Open Force Calculator' button tapped")
                        showingCalculator = true
                        debugLog("🚀 Setting showingCalculator = true")
                    }) {
                        Text("Open Force Calculator")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeColor)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, max(16, 32))
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Force")
            .tint(themeColor)
            .onAppear {
                debugLog("🟢 ContentView: onAppear called")
                
                // Load settings asynchronously to avoid blocking UI
                Task { @MainActor in
                    debugLog("📊 Loading settings from SettingsManager (async)")
                    let loadedSettings = SettingsManager.shared.loadSettings()
                    // Manually sync properties instead of replacing object to keep StateObject valid
                    settings.theme = loadedSettings.theme
                    settings.forceNumber = loadedSettings.forceNumber
                    settings.activationCount = loadedSettings.activationCount
                    settings.currentCount = loadedSettings.currentCount
                    settings.magicTrickMode = loadedSettings.magicTrickMode
                    settings.buttonTheme = loadedSettings.buttonTheme
                    settings.openToCalculator = loadedSettings.openToCalculator
                    settings.dateTimeFormat = loadedSettings.dateTimeFormat
                    settings.plusPerfectEnabled = loadedSettings.plusPerfectEnabled
                    settings.startWithScreenshot = loadedSettings.startWithScreenshot
                    
                    debugLog("📊 Settings loaded: forceNumber=\(settings.forceNumber), openToCalculator=\(settings.openToCalculator), mode=\(settings.magicTrickMode)")
                    
                    // Always sync force number text with settings
                    forceNumberText = String(settings.forceNumber)
                    debugLog("📝 Set forceNumberText to: \(forceNumberText)")
                    
                    debugLog("🖼️ Loading background image")
                    await loadBackgroundImageAsync()
                    
                    debugLog("✅ ContentView: onAppear completed")
                }
                
                // Removed auto-opening calculator on launch - only open when button is tapped
                // if settings.openToCalculator {
                //     showingCalculator = true
                // }
            }
            .onChange(of: selectedPhotoItem) {
                debugLog("🖼️ Photo item selection changed")
                Task {
                    if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self) {
                        debugLog("🖼️ Photo data loaded, size: \(data.count) bytes")
                        backgroundImage = UIImage(data: data)
                        if let image = backgroundImage {
                            debugLog("🖼️ Saving background image")
                            saveBackgroundImage(image)
                        }
                    } else {
                        debugLog("❌ Failed to load photo data")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCalculator) {
            let _ = debugLog("📱 Presenting CalculatorView fullScreenCover")
            return CalculatorView()
                .environmentObject(settings)
                .onAppear {
                    debugLog("📱 CalculatorView appeared")
                }
                .onDisappear {
                    debugLog("📱 CalculatorView dismissed")
                }
        }
        .onChange(of: showQRCodeView) { _, newValue in
            if newValue {
                debugLog("📱 showQRCodeView changed to true")
            }
        }
        .sheet(isPresented: $showQRCodeView) {
            LazyQRCodeView()
        }
    }
    
    @ViewBuilder
    private var calculatorSettingsSection: some View {
        Section(header: Text("Calculator Settings")) {
            Toggle("Open to Calculator", isOn: $settings.openToCalculator)
                .onChange(of: settings.openToCalculator) { oldValue, newValue in
                    Task { @MainActor in
                        SettingsManager.shared.saveSettings(settings)
                    }
                }
            
            Picker("Button Theme", selection: $settings.buttonTheme) {
                ForEach(ButtonTheme.allCases, id: \.self) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .tint(themeColor)
            .onChange(of: settings.buttonTheme) { oldValue, newValue in
                Task { @MainActor in
                    SettingsManager.shared.saveSettings(settings)
                }
            }
            
            Picker("Magic Trick Mode", selection: $settings.magicTrickMode) {
                ForEach(MagicTrickMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .tint(themeColor)
            .onChange(of: settings.magicTrickMode) { oldValue, newValue in
                debugLog("🎭 Magic trick mode changed: \(oldValue) → \(newValue)")
                // Just force UI update for the conditional field
                withAnimation {
                    // This forces the view to re-evaluate without changing the state
                    settings.objectWillChange.send()
                }
                Task { @MainActor in
                    SettingsManager.shared.saveSettings(settings)
                }
            }
            
            if settings.magicTrickMode == .forceNumber {
                HStack {
                    Text("Force Number")
                        .foregroundColor(.white)
                    Spacer()
                    TextField("Enter number", text: $forceNumberText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            }
                        }
                        .onChange(of: forceNumberText) { oldValue, newValue in
                            // Filter out non-numeric characters
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                forceNumberText = filtered
                                return
                            }
                            
                            // Update settings if valid number
                            if !filtered.isEmpty, let number = Int(filtered) {
                                settings.forceNumber = number
                                Task { @MainActor in
                                    SettingsManager.shared.saveSettings(settings)
                                }
                            } else if filtered.isEmpty {
                                // Allow empty field while typing
                                // Don't update settings until user finishes
                            }
                        }
                        .onChange(of: settings.forceNumber) { oldValue, newValue in
                            // Sync text field when settings change externally
                            if String(newValue) != forceNumberText {
                                forceNumberText = String(newValue)
                            }
                        }
                        .onAppear {
                            // Always sync with current settings value
                            forceNumberText = String(settings.forceNumber)
                        }
                }
            } else {
                HStack {
                    Text("Date and Time Format")
                        .foregroundColor(.white)
                    Spacer()
                    Picker("", selection: $settings.dateTimeFormat) {
                        Text("MMDDYYXXXX").tag(DateTimeFormat.mmDDYY)
                        Text("DDMMYYXXXX").tag(DateTimeFormat.ddMMYY)
                        Text("XXXXDDMMYY").tag(DateTimeFormat.xxDDMMYY)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .tint(themeColor)
                    .onChange(of: settings.dateTimeFormat) { oldValue, newValue in
                        Task { @MainActor in
                            SettingsManager.shared.saveSettings(settings)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Picker("Activation Count", selection: $settings.activationCount) {
                    ForEach(1...10, id: \.self) { count in
                        if count == 1 {
                            Text("1 (Immediate Force)").tag(count)
                        } else {
                            Text("\(count) calculations").tag(count)
                        }
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .tint(themeColor)
                .onChange(of: settings.activationCount) { oldValue, newValue in
                    Task { @MainActor in
                        SettingsManager.shared.saveSettings(settings)
                    }
                }
                
                Text(ordinalTextForActivationCount)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Plus Perfect", isOn: $settings.plusPerfectEnabled)
                    .onChange(of: settings.plusPerfectEnabled) { oldValue, newValue in
                        Task { @MainActor in
                            SettingsManager.shared.saveSettings(settings)
                        }
                    }
                
                Text("Press + and flip phone upside down for perfect addition")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Start with Screenshot", isOn: Binding(
                    get: { settings.startWithScreenshot },
                    set: { newValue in
                        settings.startWithScreenshot = newValue
                        Task { @MainActor in
                            SettingsManager.shared.saveSettings(settings)
                        }
                    }
                ))
                
                Text("App starts showing screenshot, tap anywhere to open calculator")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }
    
    private var performOnPhoneSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Text("Take a screenshot of your phone app screen and add it below to use as a background image when in performance mode on your own phone.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ZStack {
                    if let backgroundImage = backgroundImage {
                        Image(uiImage: backgroundImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 195)
                            .clipped()
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(
                                Button(action: {
                                    deleteBackgroundImage()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .font(.title2)
                                }
                                .offset(x: 8, y: -8),
                                alignment: .topTrailing
                            )
                    } else {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 100, height: 195)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.title)
                                        .foregroundColor(.gray)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Perform on Your Phone")
        }
    }
    
    private var qrCodeButton: some View {
        Button(action: handleQRCodeTap) {
            HStack {
                Image(systemName: "qrcode")
                .foregroundColor(themeColor)
                .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("QR Code & NFC")
                        .font(.headline)
                    Text("Generate QR code or write to NFC sticker")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleQRCodeTap() {
        debugLog("🔗 QR Code & NFC button tapped")
        showQRCodeView = true
    }
    
    // Legacy load method removed, new async method below
    
    private func loadBackgroundImageAsync() async {
        await Task.detached(priority: .userInitiated) {
            if let image = ImageStorageManager.shared.loadImage() {
                await MainActor.run {
                    self.backgroundImage = image
                    debugLog("✅ Background image loaded successfully via ImageStorageManager")
                }
            } else {
                debugLog("ℹ️ No background image found")
            }
        }.value
    }
    
    private func saveBackgroundImage(_ image: UIImage) {
        debugLog("💾 Saving background image")
        ImageStorageManager.shared.saveImage(image)
    }
    
    private func deleteBackgroundImage() {
        debugLog("🗑️ Deleting background image")
        backgroundImage = nil
        ImageStorageManager.shared.deleteImage()
        debugLog("✅ Background image deleted")
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private static let ordinalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter
    }()
    
    private func ordinal(_ number: Int) -> String {
        Self.ordinalFormatter.string(from: NSNumber(value: number)) ?? "\(number)th"
    }
    
    private func ordinalText(for number: Int) -> String {
        // Cache common values to avoid formatter overhead
        switch number {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        case 5: return "5th"
        default: return ordinal(number)
        }
    }
    
    private var ordinalTextForActivationCount: String {
        let count = settings.activationCount
        let ordinal: String
        switch count {
        case 1: ordinal = "1st"
        case 2: ordinal = "2nd"
        case 3: ordinal = "3rd"
        case 4: ordinal = "4th"
        case 5: ordinal = "5th"
        case 6: ordinal = "6th"
        case 7: ordinal = "7th"
        case 8: ordinal = "8th"
        case 9: ordinal = "9th"
        case 10: ordinal = "10th"
        default: ordinal = "\(count)th"
        }
        return "Force appears on the \(ordinal) equals press"
    }
}

// Lazy wrapper to prevent QRCodeNFCView from being evaluated during ContentView body
struct LazyQRCodeView: View {
    @State private var isReady = false
    
    var body: some View {
        Group {
            if isReady {
                NavigationView {
                    QRCodeNFCView()
                }
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        debugLog("📱 LazyQRCodeView: Delaying 0.1s before creating QRCodeNFCView")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            debugLog("📱 LazyQRCodeView: Now safe to create QRCodeNFCView")
                            isReady = true
                        }
                    }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
