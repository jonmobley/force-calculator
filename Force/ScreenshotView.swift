//
//  ScreenshotView.swift
//  Force
//
//  Created for screenshot mode
//

import SwiftUI
import ForceShared

struct ScreenshotView: View {
    @EnvironmentObject var settings: CalculatorSettings
    @State private var showingCalculator = false
    @State private var backgroundImage: UIImage?
    
    var body: some View {
        ZStack {
            if let backgroundImage = backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .onTapGesture {
                        debugLog("📸 Screenshot tapped - opening calculator")
                        showingCalculator = true
                    }
            } else {
                // Fallback if no screenshot is set
                Color.black
                    .ignoresSafeArea()
                    .onTapGesture {
                        debugLog("📸 Background tapped (no screenshot) - opening calculator")
                        showingCalculator = true
                    }
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
