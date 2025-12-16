import SwiftUI
import CoreNFC

struct QRCodeNFCView: View {
    @EnvironmentObject var settings: CalculatorSettings
    @State private var qrCodeImage: UIImage?
    @State private var nfcSession: NFCNDEFReaderSession?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isNFCAvailable = false
    @State private var hasLoaded = false
    
    init() {
        debugLog("📡 QRCodeNFCView: Initializing (no work done yet)")
    }
    
    // Dynamic App Clip URL with settings parameters
    private var appClipURL: String {
        var components = URLComponents(string: "https://appclip.apple.com/id")!
        
        // Base parameters
        var queryItems = [
            URLQueryItem(name: "p", value: "com.mobleypro.mobley.Force.Clip")
        ]
        
        // Add settings parameters
        queryItems.append(URLQueryItem(name: "fn", value: String(settings.forceNumber)))
        queryItems.append(URLQueryItem(name: "ac", value: String(settings.activationCount)))
        queryItems.append(URLQueryItem(name: "mt", value: settings.magicTrickMode.rawValue))
        queryItems.append(URLQueryItem(name: "dt", value: settings.dateTimeFormat.rawValue))
        queryItems.append(URLQueryItem(name: "bt", value: settings.buttonTheme.rawValue))
        queryItems.append(URLQueryItem(name: "pp", value: String(settings.plusPerfectEnabled)))
        queryItems.append(URLQueryItem(name: "sws", value: String(settings.startWithScreenshot)))
        
        components.queryItems = queryItems
        
        let url = components.url!.absoluteString
        debugLog("🔗 Generated App Clip URL: \(url)")
        return url
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // QR Code Section
                QRCodeSection(qrCodeImage: qrCodeImage, downloadAction: downloadQRCode)
                
                // NFC Section
                NFCSection(
                    isNFCAvailable: isNFCAvailable,
                    writeAction: writeToNFC
                )
                
                // Instructions
                InstructionsSection()
            }
            .padding()
        }
        .navigationTitle("QR Code & NFC")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !hasLoaded else { 
                debugLog("📡 QRCodeNFCView: Already loaded, skipping")
                return 
            }
            hasLoaded = true
            
            debugLog("📡 QRCodeNFCView: onAppear - Starting background tasks")
            
            // Check NFC availability asynchronously with delay
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                debugLog("📡 Checking NFC availability...")
                isNFCAvailable = NFCNDEFReaderSession.readingAvailable
                debugLog("📡 NFC available: \(isNFCAvailable)")
            }
            
            // Generate QR code asynchronously with slight delay
            Task {
                debugLog("📡 Generating QR code in background...")
                if let image = await QRCodeGenerator.generateQRCodeAsync(from: appClipURL) {
                    qrCodeImage = image
                }
                debugLog("📡 QR code generation complete")
            }
            
            debugLog("📡 QRCodeNFCView: onAppear completed immediately (work happening in background)")
        }
        .alert("NFC Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func downloadQRCode() {
        guard let qrCodeImage = qrCodeImage else { return }
        
        PhotoLibraryManager.saveImage(qrCodeImage) { result in
            switch result {
            case .success(let message):
                alertMessage = message
                showingAlert = true
            case .failure(let error):
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    private func writeToNFC() {
        let writer = NFCWriter(url: appClipURL) { message in
            DispatchQueue.main.async {
                self.alertMessage = message
                self.showingAlert = true
            }
        }
        
        nfcSession = writer.writeToNFC()
    }
}

// MARK: - QR Code Section

struct QRCodeSection: View {
    let qrCodeImage: UIImage?
    let downloadAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("QR Code")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Scan this QR code to open the Force Calculator App Clip")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // QR Code Display
            if let qrCodeImage = qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .overlay(
                        ProgressView()
                    )
            }
            
            // Download Button
            Button(action: downloadAction) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save to Photos")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(qrCodeImage == nil)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - NFC Section

struct NFCSection: View {
    let isNFCAvailable: Bool
    let writeAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("NFC Sticker")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Write the App Clip link to an NFC sticker for easy sharing")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: writeAction) {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                    Text("Write to NFC Sticker")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isNFCAvailable ? Color.orange : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isNFCAvailable)
            
            if !isNFCAvailable {
                Text("NFC is not available on this device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Instructions Section

struct InstructionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Use")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("1.")
                        .fontWeight(.semibold)
                    Text("Save the QR code to your photos and share it with others")
                }
                
                HStack(alignment: .top) {
                    Text("2.")
                        .fontWeight(.semibold)
                    Text("Write to an NFC sticker and place it where people can tap their phones")
                }
                
                HStack(alignment: .top) {
                    Text("3.")
                        .fontWeight(.semibold)
                    Text("When scanned or tapped, it will open the Force Calculator App Clip")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

#Preview {
    NavigationView {
        QRCodeNFCView()
    }
}
