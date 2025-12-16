import Foundation
import UIKit
import Combine

class PlusPerfectHandler: ObservableObject {
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    @Published var mode: PlusPerfectState = .inactive
    var savedNumber: Double = 0
    
    // Check current orientation - always up to date
    var isUpsideDown: Bool {
        return UIDevice.current.orientation == .portraitUpsideDown
    }
    
    private var orientationObserver: NSObjectProtocol?
    private var previousOrientation: UIDeviceOrientation = .unknown
    
    // Store the handler callback so we can notify the view when mode changes
    private var orientationChangeHandler: (() -> Void)?
    
    // Check if running on simulator
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    func startMonitoring(handler: @escaping () -> Void) {
        debugLog("🎭 Plus Perfect: Starting orientation monitoring")
        if isSimulator {
            debugLog("⚠️ WARNING: Running on iOS Simulator")
            debugLog("⚠️ iOS Simulator has LIMITED support for upside-down orientation detection")
            debugLog("⚠️ Plus Perfect may not work correctly - test on a physical device for best results")
        }
        hapticGenerator.prepare()
        orientationChangeHandler = handler
        previousOrientation = UIDevice.current.orientation
        debugLog("🎭 Plus Perfect: Initial orientation = \(orientationDescription(previousOrientation))")
        debugLog("🎭 Plus Perfect: Current mode = \(mode)")
        debugLog("🎭 Plus Perfect: Running on \(isSimulator ? "SIMULATOR" : "PHYSICAL DEVICE")")
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.handleOrientationChange(handler: handler)
        }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
    
    private func orientationDescription(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "Portrait Upside Down ⬇️"
        case .landscapeLeft: return "Landscape Left"
        case .landscapeRight: return "Landscape Right"
        case .faceUp: return "Face Up"
        case .faceDown: return "Face Down"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
    
    func stopMonitoring() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
        }
    }
    
    private func handleOrientationChange(handler: @escaping () -> Void) {
        let orientation = UIDevice.current.orientation
        let wasUpsideDown = (previousOrientation == .portraitUpsideDown)
        let isNowUpsideDown = (orientation == .portraitUpsideDown)
        
        // Debug: Log all orientation changes
        debugLog("🔄 Orientation changed: \(orientationDescription(previousOrientation)) → \(orientationDescription(orientation))")
        debugLog("   Mode: \(mode)")
        debugLog("   Was upside down: \(wasUpsideDown), Now upside down: \(isNowUpsideDown)")
        if isSimulator && (isNowUpsideDown || wasUpsideDown) {
            debugLog("⚠️ Simulator: Upside-down orientation detection may be unreliable")
        }
        
        previousOrientation = orientation
        
        // Handle waitingForFlip state - activate when phone flips upside down after + was pressed
        if mode == .waitingForFlip {
            if isNowUpsideDown && !wasUpsideDown {
                debugLog("🎭✅ Plus Perfect: Phone flipped upside down after + was pressed - ACTIVATING!")
                hapticGenerator.impactOccurred(intensity: 1.0)
                mode = .activated
                // Immediately transition to upsideDown since we're already upside down
                mode = .upsideDown
                debugLog("🎭⬇️ Plus Perfect: Mode set to upsideDown - input will be ignored")
                return
            }
            // Still waiting for flip, don't do anything else yet
            debugLog("🎭⏳ Plus Perfect: Still waiting for flip (current: \(orientationDescription(orientation)))")
            return
        }
        
        // Only act if Plus Perfect is active
        guard mode == .activated || mode == .upsideDown else { 
            debugLog("🎭❌ Plus Perfect: Not active (mode: \(mode)), ignoring orientation change")
            return 
        }
        
        if isNowUpsideDown && !wasUpsideDown {
            // Phone just flipped upside down (already activated)
            debugLog("🎭⬇️ Plus Perfect: Phone flipped UPSIDE DOWN - input will be ignored")
            hapticGenerator.impactOccurred(intensity: 0.7)
            mode = .upsideDown
        } else if !isNowUpsideDown && wasUpsideDown {
            // Phone just flipped back to normal
            debugLog("🎭⬆️ Plus Perfect: Phone flipped RIGHT-SIDE UP - calculating perfect addend NOW!")
            hapticGenerator.impactOccurred(intensity: 1.0)
            handler()
        }
    }
    
    func calculatePerfectAddend(
        display: inout String,
        operation: inout CalculatorOperation?,
        previousNumber: inout Double,
        currentNumber: inout Double,
        userIsTyping: inout Bool,
        settings: CalculatorSettings
    ) {
        let forceNumber = settings.magicTrickMode == .forceNumber ? 
            Double(settings.forceNumber) : 
            Double(settings.getCurrentDateTimeNumber())
        
        let perfectAddend = forceNumber - savedNumber
        
        debugLog("🎭🧮 Plus Perfect: CALCULATING PERFECT ADDEND")
        debugLog("   Saved number: \(savedNumber)")
        debugLog("   Force number: \(forceNumber)")
        debugLog("   Perfect addend: \(perfectAddend) (Force - Saved)")
        debugLog("   Formula: \(forceNumber) - \(savedNumber) = \(perfectAddend)")
        
        display = CalculatorFormatter.formatResult(perfectAddend)
        operation = .add
        previousNumber = savedNumber
        currentNumber = perfectAddend
        mode = .calculated
        userIsTyping = false
        
        debugLog("🎭✅ Plus Perfect: Display updated to show \(display)")
        debugLog("   Operation set to: add")
        debugLog("   Previous number: \(previousNumber)")
        debugLog("   Current number: \(currentNumber)")
    }
}
