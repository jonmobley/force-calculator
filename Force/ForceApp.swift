//
//  ForceApp.swift
//  Force
//
//  Created by Jon Mobley on 6/14/25.
//

import SwiftUI
import Combine

@main
struct ForceApp: App {
    @StateObject private var settings = CalculatorSettings()
    @State private var isReady = false
    
    init() {
        debugLog("🚀🚀🚀 ForceApp: Application Starting 🚀🚀🚀")
    }
    
    var body: some Scene {
        let _ = debugLog("🏗️ ForceApp: Building Scene")
        return WindowGroup {
            Group {
                if isReady {
                    ScreenshotModeView(settings: settings)
                } else {
                    // Show loading while settings load
                    Color.black
                        .ignoresSafeArea()
                        .onAppear {
                            // Load settings synchronously on first appear
                            settings.loadSettings()
                            isReady = true
                        }
                }
            }
        }
    }
}

// Separate view to handle the conditional logic
struct ScreenshotModeView: View {
    @ObservedObject var settings: CalculatorSettings
    @State private var showScreenshot = false
    
    var body: some View {
        Group {
            if showScreenshot {
                ScreenshotView()
                    .environmentObject(settings)
                    .onAppear {
                        debugLog("📸 Starting in screenshot mode")
                    }
            } else {
                ContentView()
                    .environmentObject(settings)
                    .onAppear {
                        debugLog("🏠 ForceApp: Main window appeared")
                    }
            }
        }
        .onAppear {
            updateScreenshotMode()
        }
        .onReceive(settings.$startWithScreenshot) { _ in
            updateScreenshotMode()
        }
    }
    
    private func updateScreenshotMode() {
        let screenshotExists = UserDefaults.standard.data(forKey: "backgroundImage") != nil
        // Access the property value directly
        let screenshotEnabled = settings.startWithScreenshot
        showScreenshot = screenshotEnabled && screenshotExists
    }
}
