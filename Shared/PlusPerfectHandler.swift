import Foundation
import UIKit
import Combine

/// Drives Plus Perfect from physical device orientation. Plus is pressed with the phone
/// upright, then turning it over and back arms and fires the trick.
public class PlusPerfectHandler: ObservableObject {
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    @Published public var mode: PlusPerfectState = .inactive
    public var savedNumber: Double = 0

    /// Delay between the two pulses of the armed confirmation.
    private let armedPulseGap: TimeInterval = 0.12

    private var orientationObserver: NSObjectProtocol?

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
        guard orientationObserver == nil else {
            debugLog("🎭 Plus Perfect: orientation monitoring already running")
            return
        }
        debugLog("🎭 Plus Perfect: Starting orientation monitoring")
        if isSimulator {
            debugLog("⚠️ Plus Perfect orientation is unreliable in the simulator. Confirm on a device.")
        }
        hapticGenerator.prepare()
        // Orientation only reports a real value once notifications are being generated.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleOrientationChange(handler: handler)
        }
    }

    public func stopMonitoring() {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
        }
    }

    /// Records the plus so a later turn of the phone can arm the trick. The addition
    /// itself proceeds as normal, so an unflipped plus behaves like any other calculator.
    public func markPendingAdd(operand: Double) {
        savedNumber = operand
        mode = .pendingAdd
    }

    /// Drops any pending or armed trick. Called when the performer does something
    /// that ends the addition, such as equals, clear, or a different operation.
    public func reset() {
        mode = .inactive
        savedNumber = 0
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

    // MARK: - Force value

    private func forcedValue(_ settings: CalculatorSettings) -> Double {
        if settings.magicTrickMode == .forceNumber {
            return Double(settings.forceNumber)
        }
        return Double(settings.getCurrentDateTimeNumber())
    }

    // MARK: - Orientation

    /// Flat readings are dropped rather than acted on, so resting the phone on a table
    /// mid-trick neither arms it nor gives the reveal away.
    private func handleOrientationChange(handler: @escaping () -> Void) {
        guard let orientation = PlusPerfectMath.heldOrientation(UIDevice.current.orientation) else { return }
        if PlusPerfectMath.shouldArm(mode: mode, heldOrientation: orientation) {
            arm()
            return
        }
        guard PlusPerfectMath.shouldReveal(mode: mode, heldOrientation: orientation) else { return }
        hapticGenerator.impactOccurred(intensity: 1.0)
        handler()
    }

    private func arm() {
        mode = .armed
        debugLog("🎭 Plus Perfect: armed holding \(savedNumber)")
        playArmedPulse()
    }

    // MARK: - Haptics

    /// Two quick taps, so an armed trick is distinguishable from an accidental knock.
    private func playArmedPulse() {
        hapticGenerator.impactOccurred(intensity: 0.5)
        hapticGenerator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + armedPulseGap) { [weak self] in
            self?.hapticGenerator.impactOccurred(intensity: 0.9)
        }
    }
}
