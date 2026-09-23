import SwiftUI
import CoreNFC
import ForceShared

struct QRCodeNFCView: View {
    @EnvironmentObject var settings: CalculatorSettings
    @State private var qrCodeImage: UIImage?
    @State private var nfcWriter: NFCWriter?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isNFCAvailable = false
    @State private var hasLoaded = false
    
    init() {
        debugLog("📡 QRCodeNFCView: Initializing (no work done yet)")
    }
    
    /// Stable invocation URL. Settings travel through `ForceConfigService`, so
    /// this value never changes and a written sticker never goes stale.
    private var appClipURL: String {
        let url = AppClipQuery.stableURL(performer: PerformerCredentials.identifier).absoluteString
        debugLog("🔗 App Clip URL: \(url)")
        return url
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // QR Code Section
                QRCodeSection(
                    qrCodeImage: qrCodeImage,
                    tint: settings.buttonTheme.color,
                    downloadAction: downloadQRCode
                )
                
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
        guard nfcWriter == nil else { return }
        let writer = NFCWriter(url: appClipURL) { outcome in
            nfcWriter = nil
            // The system NFC sheet already confirms success and cancellation.
            if case .failure(let message) = outcome {
                alertMessage = message
                showingAlert = true
            }
        }
        nfcWriter = writer
        writer.start()
    }
}

// MARK: - QR Code Section

struct QRCodeSection: View {
    let qrCodeImage: UIImage?
    /// The performer's chosen operator colour, so this screen matches the rest of the
    /// app rather than standing out in the system blue.
    let tint: Color
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
                .background(tint)
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
    NavigationStack {
        QRCodeNFCView()
    }
    .environmentObject(CalculatorSettings())
}
