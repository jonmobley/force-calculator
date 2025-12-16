//
//  ScreenshotView.swift
//  Force
//
//  Created for screenshot mode
//

import SwiftUI

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
        .onAppear {
            loadBackgroundImage()
        }
    }
    
    private func loadBackgroundImage() {
        if let image = ImageStorageManager.shared.loadImage() {
            backgroundImage = image
            debugLog("📸 Screenshot loaded successfully")
        } else {
            debugLog("📸 No screenshot found")
        }
    }
}
