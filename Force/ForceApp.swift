//
//  ForceApp.swift
//  Force
//
//  Created by Jon Mobley on 6/14/25.
//

import SwiftUI
import Combine
import ForceShared

/// Which screen sits at the root of the window.
///
/// The choice is made once, synchronously, right after settings load, so a launch
/// straight into the calculator or a screenshot never flashes the settings list on
/// its way. Later, dismissing the calculator or the screenshot swaps the root back
/// to settings; the transition uses no animation, matching how an app just is
/// what it opens as rather than sliding into itself.
enum RootScreen: Equatable {
    case settings
    case calculator
    case screenshot
}

@main
struct ForceApp: App {
    // Deliberately `@State` rather than `@StateObject`: the scene only needs to
    // own the settings, not observe them. Observing here would rebuild the whole
    // tree on every stored change.
    @State private var settings = CalculatorSettings()
    @State private var isReady = false
    @State private var rootScreen: RootScreen = .settings
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
                    RootScreenHost(rootScreen: $rootScreen)
                        .environmentObject(settings)
                        .environmentObject(configPublisher)
                } else {
                    // Show black while settings load, so no default UI flashes
                    // before we know whether the calculator or screenshot should
                    // be the root.
                    Color.black
                        .ignoresSafeArea()
                        .onAppear(perform: bootstrap)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    settings.flushPendingSave()
                }
            }
        }
    }

    private func bootstrap() {
        settings.loadSettings()
        settings.beginAutosave()
        // The unit tests are hosted in this app, so every test run launches it. Publishing
        // then would claim a fresh id on the live service each time.
        if !Self.isHostingUnitTests {
            configPublisher.start(observing: settings)
        }
        rootScreen = decideLaunchRoot()
        isReady = true
    }

    /// True when XCTest launched the app only to host the unit tests.
    private static var isHostingUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Picks the root the app should open into, synchronously, so the first
    /// visible frame is already the right screen. Screenshot wins over the plain
    /// calculator launch when both are on, matching the priority the old flow
    /// implied by checking screenshot first.
    private func decideLaunchRoot() -> RootScreen {
        if settings.startWithScreenshot && ImageStorageManager.shared.hasImage() {
            debugLog("📸 Launch root: screenshot")
            return .screenshot
        }
        if settings.openToCalculator {
            debugLog("🧮 Launch root: calculator")
            return .calculator
        }
        debugLog("🏠 Launch root: settings")
        return .settings
    }
}

/// Renders whichever root the app is currently showing. Views change the root by
/// calling back into this host, so the switch is a plain state change rather than
/// a sheet or a cover presentation.
private struct RootScreenHost: View {
    @Binding var rootScreen: RootScreen

    var body: some View {
        Group {
            switch rootScreen {
            case .settings:
                ContentView()
                    .onAppear { debugLog("🏠 ForceApp: Main window appeared") }
            case .calculator:
                CalculatorView(onDismiss: { rootScreen = .settings })
                    .onAppear { debugLog("🧮 ForceApp: Calculator root appeared") }
            case .screenshot:
                ScreenshotView(onOpenCalculator: { rootScreen = .calculator })
                    .onAppear { debugLog("📸 ForceApp: Screenshot root appeared") }
            }
        }
        // Root swaps are the app's launch state changing, not an in-screen
        // navigation, so they run without a transition rather than fading or
        // sliding between two different apps' worth of chrome.
        .transaction { $0.disablesAnimations = true }
    }
}
