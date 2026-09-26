import SwiftUI
import CoreNFC
import ForceShared

/// The QR code and NFC sticker writer that hand out the App Clip link.
struct QRCodeNFCView: View {
    @EnvironmentObject var settings: CalculatorSettings
    @EnvironmentObject private var configPublisher: ForceConfigPublisher
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
                if configPublisher.hasClaimedIdentifier {
                    QRCodeSection(
                        qrCodeImage: qrCodeImage,
                        tint: settings.buttonTheme.color,
                        downloadAction: downloadQRCode
                    )
                    NFCSection(
                        isNFCAvailable: isNFCAvailable,
                        writeAction: writeToNFC
                    )
                } else {
                    ClaimPendingSection(state: configPublisher.state)
                }
                InstructionsSection()
            }
            .padding()
        }
        .navigationTitle("QR Code & NFC")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: checkNFCOnce)
        // The link is only built once the service has bound the id to this install.
        .task(id: configPublisher.hasClaimedIdentifier) {
            guard configPublisher.hasClaimedIdentifier, qrCodeImage == nil else { return }
            qrCodeImage = await QRCodeGenerator.generateQRCodeAsync(from: appClipURL)
        }
        .alert("NFC Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private func checkNFCOnce() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            isNFCAvailable = NFCNDEFReaderSession.readingAvailable
            debugLog("📡 NFC available: \(isNFCAvailable)")
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
        guard nfcWriter == nil, configPublisher.hasClaimedIdentifier else { return }
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

// MARK: - Claim Pending Section

/// Stands in for the QR code and NFC writer until the service has accepted this install's id.
struct ClaimPendingSection: View {
    let state: ForceConfigPublisher.State

    var body: some View {
        VStack(spacing: 12) {
            if case .outOfDate(let reason) = state {
                Image(systemName: "exclamationmark.icloud")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("Can't set up your link yet")
                    .font(.headline)
                Text("\(reason). Your QR code and NFC sticker appear once Force can reach "
                     + "its server. It retries automatically.")
            } else {
                ProgressView()
                Text("Setting up your link...")
                    .font(.headline)
                Text("Your QR code and NFC sticker appear once your settings are saved online.")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
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
    .environmentObject(ForceConfigPublisher())
}
