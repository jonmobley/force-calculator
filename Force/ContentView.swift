import SwiftUI
import PhotosUI
import ForceShared

/// Performer home. Force, including Perfect Plus, is edited here. Every other
/// setting opens its own page from a row with an icon, a title, and a chevron.
struct ContentView: View {
    @EnvironmentObject private var settings: CalculatorSettings
    @EnvironmentObject private var configPublisher: ForceConfigPublisher
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var peekReader = ForcePeekReader()
    @State private var forceNumberText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var backgroundImage: UIImage?
    @State private var showingCalculator = false
    @State private var showingPeekStage = false

    private var themeColor: Color { settings.buttonTheme.color }

    var body: some View {
        NavigationStack {
            Form {
                ForceTrickSection(forceNumberText: $forceNumberText)
                trickLinks
                performanceLinks
                appLinks
            }
            .scrollDismissesKeyboard(.interactively)
            // A safe-area inset rather than a sibling in a stack: stacked, the bar simply
            // covered the end of the form, leaving the last row half hidden and awkward
            // to tap even scrolled all the way down.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                openCalculatorBar
            }
            .navigationTitle("Force")
            .navigationDestination(for: ForceSettingsPage.self) { route in
                page(for: route)
            }
            .tint(themeColor)
            .onAppear(perform: appear)
            .onChange(of: selectedPhotoItem) { _, _ in loadSelectedPhoto() }
            .onChange(of: settings.livePeekEnabled) { _, _ in updatePeekReader() }
            .onChange(of: scenePhase) { _, _ in updatePeekReader() }
            .onChange(of: settings.forceNumber) { _, newValue in
                if String(newValue) != forceNumberText {
                    forceNumberText = String(newValue)
                }
            }
            .background {
                ForcePeekMonitor(reader: peekReader, showingStage: $showingPeekStage)
            }
        }
        .fullScreenCover(isPresented: $showingCalculator) {
            CalculatorView().environmentObject(settings)
        }
        .fullScreenCover(isPresented: $showingPeekStage) {
            PeekStageView(reader: peekReader)
        }
    }

    // MARK: - List

    private var trickLinks: some View {
        Section {
            settingsLink(.livePeek, title: "Live Peek", symbol: "eye",
                         color: .blue, detail: livePeekDetail)
        }
    }

    private var performanceLinks: some View {
        Section {
            settingsLink(.phone, title: "Perform on Your Phone", symbol: "iphone",
                         color: .indigo, detail: phoneDetail)
            settingsLink(.share, title: "QR Code & NFC", symbol: "qrcode",
                         color: .teal, detail: nil)
        }
    }

    private var appLinks: some View {
        Section {
            settingsLink(.appearance, title: "Button Theme", symbol: "paintpalette",
                         color: .pink, detail: settings.buttonTheme.rawValue)
            settingsLink(.sync, title: "Sync", symbol: "arrow.triangle.2.circlepath",
                         color: Color(.systemGray), detail: syncDetail)
        }
    }

    private func settingsLink(
        _ route: ForceSettingsPage,
        title: String,
        symbol: String,
        color: Color,
        detail: String?
    ) -> some View {
        NavigationLink(value: route) {
            SettingsLinkRow(title: title, systemImage: symbol, color: color, detail: detail)
        }
    }

    @ViewBuilder
    private func page(for route: ForceSettingsPage) -> some View {
        switch route {
        case .livePeek:
            ForceLivePeekPage(reader: peekReader, showingStage: $showingPeekStage)
        case .phone:
            ForcePhonePage(
                selectedPhotoItem: $selectedPhotoItem,
                backgroundImage: backgroundImage,
                onDelete: deleteBackgroundImage
            )
        case .share:
            QRCodeNFCView()
        case .appearance:
            ForceAppearancePage()
        case .sync:
            ForceSyncPage(publisher: configPublisher)
        }
    }

    // MARK: - Row values

    private var livePeekDetail: String {
        guard settings.livePeekEnabled else { return "Off" }
        if case .value(let peek) = peekReader.state, let latest = peek.latest {
            return latest.line
        }
        return "On"
    }

    private var phoneDetail: String? {
        if settings.startWithScreenshot { return "Screenshot" }
        if settings.openToCalculator { return "Calculator" }
        return nil
    }

    private var syncDetail: String {
        switch configPublisher.state {
        case .idle: return "Not Published"
        case .publishing: return "Publishing"
        case .synced: return "Live"
        case .outOfDate: return "Out of Date"
        }
    }

    // MARK: - Calculator bar

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

    // MARK: - Lifecycle

    private func appear() {
        forceNumberText = String(settings.forceNumber)
        updatePeekReader()
        Task { await loadBackgroundImageAsync() }
    }

    /// Polls while the app is open and live peek is on. Opening the calculator or
    /// the big display must not stop it; those are still this performance.
    /// Backgrounding the app does stop it.
    private func updatePeekReader() {
        if settings.livePeekEnabled, scenePhase == .active {
            peekReader.start()
        } else {
            peekReader.stop()
        }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(CalculatorSettings())
            .environmentObject(ForceConfigPublisher())
    }
}
