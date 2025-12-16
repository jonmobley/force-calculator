//
//  ForceClipApp.swift
//  ForceClip
//
//  Created by Jon Mobley on 6/10/25.
//

import SwiftUI
import Foundation

@main
struct ForceClipApp: App {
    // Initialize settings with defaults/loaded values
    @StateObject private var settings: CalculatorSettings = {
        let s = CalculatorSettings()
        s.loadSettings()
        return s
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let url = userActivity.webpageURL else { return }
                    handleIncomingURL(url)
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("🔗 ForceClip: Received URL: \(url.absoluteString)")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else {
            print("❌ ForceClip: Could not parse URL components")
            return
        }
        
        // Update settings based on URL parameters
        // 'p' is usually bundle ID, we can ignore or verify it
        
        // Force Number (fn)
        if let fnStr = queryItems.first(where: { $0.name == "fn" })?.value,
           let fn = Int(fnStr) {
            print("✅ ForceClip: Updating Force Number to \(fn)")
            settings.forceNumber = fn
        }
        
        // Activation Count (ac)
        if let acStr = queryItems.first(where: { $0.name == "ac" })?.value,
           let ac = Int(acStr) {
            print("✅ ForceClip: Updating Activation Count to \(ac)")
            settings.activationCount = ac
        }
        
        // Magic Trick Mode (mt)
        if let mtStr = queryItems.first(where: { $0.name == "mt" })?.value,
           let mode = MagicTrickMode(rawValue: mtStr) {
            print("✅ ForceClip: Updating Magic Trick Mode to \(mode.rawValue)")
            settings.magicTrickMode = mode
        }
        
        // Date Time Format (dt)
        if let dtStr = queryItems.first(where: { $0.name == "dt" })?.value,
           let format = DateTimeFormat(rawValue: dtStr) {
            print("✅ ForceClip: Updating Date Time Format to \(format.rawValue)")
            settings.dateTimeFormat = format
        }
        
        // Button Theme (bt)
        if let btStr = queryItems.first(where: { $0.name == "bt" })?.value,
           let theme = ButtonTheme(rawValue: btStr) {
            print("✅ ForceClip: Updating Button Theme to \(theme.rawValue)")
            settings.buttonTheme = theme
        }
        
        // Plus Perfect Enabled (pp)
        if let ppStr = queryItems.first(where: { $0.name == "pp" })?.value,
           let pp = Bool(ppStr) {
            print("✅ ForceClip: Updating Plus Perfect Enabled to \(pp)")
            settings.plusPerfectEnabled = pp
        }
        
        // Start With Screenshot (sws)
        if let swsStr = queryItems.first(where: { $0.name == "sws" })?.value,
           let sws = Bool(swsStr) {
            print("✅ ForceClip: Updating Start With Screenshot to \(sws)")
            settings.startWithScreenshot = sws
        }
        
        // Save these settings locally so they persist for this session/device
        settings.saveSettings()
    }
}
