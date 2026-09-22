import Foundation
import UIKit
import Combine

/// Tracks device orientation so upside-down plus can arm Plus Perfect.
public class PlusPerfectHandler: ObservableObject {
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    @Published public var mode: PlusPerfectState = .inactive
    public var savedNumber: Double = 0

    /// True when the device reports portrait upside down.
    /// The host allows that orientation, so the interface can rotate with the phone.
    public var isUpsideDown: Bool {
        UIDevice.current.orientation == .portraitUpsideDown
    }

    private var orientationObserver: NSObjectProtocol?
    private var previousOrientation: UIDeviceOrientation = .unknown
    private var orientationChangeHandler: (() -> Void)?

    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    public init() {}

    /// Starts orientation notifications. `handler` runs when the phone returns upright after the trick is armed.
    public func startMonitoring(handler: @escaping () -> Void) {
        debugLog("🎭 Plus Perfect: Starting orientation monitoring")
        if isSimulator {
            debugLog("⚠️ Plus Perfect orientation is unreliable in the simulator. Confirm on a device.")
        }
        hapticGenerator.prepare()
        orientationChangeHandler = handler
        previousOrientation = UIDevice.current.orientation
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleOrientationChange(handler: handler)
        }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    public func stopMonitoring() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
        }
    }

    /// Shows the addend that reaches the force number, ready for equals.
    public func calculatePerfectAddend(
        display: inout String,
        operation: inout CalculatorOperation?,
        previousNumber: inout Double,
        currentNumber: inout Double,
        userIsTyping: inout Bool,
        settings: CalculatorSettings
    ) {
        let forceNumber = forcedValue(settings)
        let perfectAddend = PlusPerfectMath.perfectAddend(
            savedNumber: savedNumber,
            forceNumber: forceNumber
        )
        display = CalculatorFormatter.formatResult(perfectAddend)
        operation = .add
        previousNumber = savedNumber
        currentNumber = perfectAddend
        mode = .calculated
        userIsTyping = false
        debugLog("🎭 Plus Perfect: addend \(perfectAddend) for force \(forceNumber)")
    }

    // MARK: - Orientation

    private func forcedValue(_ settings: CalculatorSettings) -> Double {
        if settings.magicTrickMode == .forceNumber {
            return Double(settings.forceNumber)
        }
        return Double(settings.getCurrentDateTimeNumber())
    }

    private func handleOrientationChange(handler: @escaping () -> Void) {
        let orientation = UIDevice.current.orientation
        let wasUpsideDown = previousOrientation == .portraitUpsideDown
        let isNowUpsideDown = orientation == .portraitUpsideDown
        previousOrientation = orientation
        guard mode == .activated || mode == .upsideDown else { return }
        if isNowUpsideDown && !wasUpsideDown {
            hapticGenerator.impactOccurred(intensity: 0.7)
            mode = .upsideDown
        } else if !isNowUpsideDown && wasUpsideDown {
            hapticGenerator.impactOccurred(intensity: 1.0)
            handler()
        }
    }
}
