//
//  ScreenshotView.swift
//  Force
//
//  Created for screenshot mode
//

import SwiftUI
import ForceShared

struct ScreenshotView: View {
    /// Called when the spectator taps to reveal the calculator. Set when the
    /// screenshot is the window's root and the reveal has to swap the root out
    /// instead of stacking a cover; left nil when presented as a cover, where the
    /// local `showingCalculator` state handles it. Skipping the cover on launch
    /// keeps the reveal instant, which is the whole point of the disguise.
    var onOpenCalculator: (() -> Void)?

    @EnvironmentObject var settings: CalculatorSettings
    @State private var showingCalculator = false
    @State private var backgroundImage: UIImage?

    init(onOpenCalculator: (() -> Void)? = nil) {
        self.onOpenCalculator = onOpenCalculator
    }

    var body: some View {
        ZStack {
            if let backgroundImage = backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .onTapGesture(perform: openCalculator)
            } else {
                // Fallback if no screenshot is set
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture(perform: openCalculator)
            }
        }
        .fullScreenCover(isPresented: $showingCalculator) {
            CalculatorView()
                .environmentObject(settings)
        }
        .task {
            await loadBackgroundImage()
        }
    }

    /// Prefers the caller-supplied opener so the screenshot root can swap in the
    /// calculator without an animation. Falls back to the local cover for callers
    /// that present the screenshot themselves.
    private func openCalculator() {
        debugLog("📸 Screenshot tapped - opening calculator")
        if let onOpenCalculator {
            onOpenCalculator()
        } else {
            showingCalculator = true
        }
    }

    private func loadBackgroundImage() async {
        let image = await Task.detached(priority: .userInitiated) {
            ImageStorageManager.shared.loadImage()
        }.value
        guard let image else {
            debugLog("📸 No screenshot found")
            return
        }
        backgroundImage = image
        debugLog("📸 Screenshot loaded successfully")
    }
}
