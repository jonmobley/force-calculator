import SwiftUI
import PhotosUI
import ForceShared

struct ContentView: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @EnvironmentObject private var configPublisher: ForceConfigPublisher
    @State private var forceNumberText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var backgroundImage: UIImage?
    @State private var showingCalculator = false
    @State private var showQRCodeView = false

    private var themeColor: Color { settings.buttonTheme.color }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    ForceCalculatorSettingsSection(forceNumberText: $forceNumberText)
                    ForcePhonePerformanceSection(
                        selectedPhotoItem: $selectedPhotoItem,
                        backgroundImage: backgroundImage,
                        onDelete: deleteBackgroundImage
                    )
                    ForceSyncSection(publisher: configPublisher)
                    Section {
                        ForceQRCodeButton(tint: themeColor, action: { showQRCodeView = true })
                    } header: {
                        Text("Share App Clip")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                openCalculatorBar
            }
            .navigationTitle("Force")
            .tint(themeColor)
            .onAppear(perform: appear)
            .onChange(of: selectedPhotoItem) { _, _ in loadSelectedPhoto() }
            .onChange(of: settings.forceNumber) { _, newValue in
                if String(newValue) != forceNumberText {
                    forceNumberText = String(newValue)
                }
            }
        }
        .fullScreenCover(isPresented: $showingCalculator) {
            CalculatorView().environmentObject(settings)
        }
        .sheet(isPresented: $showQRCodeView) {
            LazyQRCodeView().environmentObject(settings)
        }
    }

    private var openCalculatorBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: { showingCalculator = true }) {
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

    private func appear() {
        forceNumberText = String(settings.forceNumber)
        if settings.openToCalculator {
            showingCalculator = true
        }
        Task { await loadBackgroundImageAsync() }
    }

    private func loadSelectedPhoto() {
        Task {
            guard let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            backgroundImage = image
            ImageStorageManager.shared.saveImage(image)
        }
    }

    private func loadBackgroundImageAsync() async {
        let image = await Task.detached(priority: .userInitiated) {
            ImageStorageManager.shared.loadImage()
        }.value
        backgroundImage = image
    }

    private func deleteBackgroundImage() {
        backgroundImage = nil
        ImageStorageManager.shared.deleteImage()
    }
}

struct LazyQRCodeView: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @State private var isReady = false

    var body: some View {
        Group {
            if isReady {
                NavigationView { QRCodeNFCView().environmentObject(settings) }
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
            .environmentObject(CalculatorSettings())
            .environmentObject(ForceConfigPublisher())
    }
}
