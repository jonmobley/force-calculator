//
//  ForceApp.swift
//  Force
//
//  Created by Jon Mobley on 6/14/25.
//

import SwiftUI
import Combine
import ForceShared

@main
struct ForceApp: App {
    // Deliberately `@State` rather than `@StateObject`: the scene only needs to
    // own the settings, not observe them. Observing here would rebuild the whole
    // tree on every stored change.
    @State private var settings = CalculatorSettings()
    @State private var isReady = false
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var configPublisher = ForceConfigPublisher()
    
    init() {
        debugLog("🚀🚀🚀 ForceApp: Application Starting 🚀🚀🚀")
    }
    
    var body: some Scene {
        let _ = debugLog("🏗️ ForceApp: Building Scene")
        return WindowGroup {
            Group {
                if isReady {
                    ScreenshotModeView(settings: settings)
                        .environmentObject(configPublisher)
                } else {
                    // Show loading while settings load
                    Color.black
                        .ignoresSafeArea()
                        .onAppear {
                            // Load settings synchronously on first appear
                            settings.loadSettings()
                            settings.beginAutosave()
                            configPublisher.start(observing: settings)
                            isReady = true
                        }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    settings.flushPendingSave()
                }
            }
        }
    }
}

// Separate view to handle the conditional logic
struct ScreenshotModeView: View {
    // Not observed: this view reacts only to `startWithScreenshot`, which it
    // receives through the publisher below.
    let settings: CalculatorSettings
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
        guard settings.startWithScreenshot else {
            showScreenshot = false
            return
        }
        Task {
            // Only existence matters here, and the check runs off the main
            // thread so a stored screenshot cannot delay the first frame.
            let screenshotExists = await Task.detached(priority: .userInitiated) {
                ImageStorageManager.shared.hasImage()
            }.value
            showScreenshot = screenshotExists
        }
    }
}
