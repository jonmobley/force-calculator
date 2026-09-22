import Foundation
import UIKit
import CoreMotion
import Combine

/// Drives Plus Perfect from the phone's physical attitude. Plus is pressed with the phone
/// upright, then turning it over and back arms and fires the trick.
///
/// Gravity is read directly rather than through `UIDevice.orientation`, because that
/// reports `faceUp` as soon as the screen tilts toward horizontal and so cannot say which
/// way round a phone being held out for someone to tap is.
public class PlusPerfectHandler: ObservableObject {
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let motionManager = CMMotionManager()
    @Published public var mode: PlusPerfectState = .inactive
    public var savedNumber: Double = 0

    /// Delay between the two pulses of the armed confirmation.
    private let armedPulseGap: TimeInterval = 0.12

    /// 10Hz is far quicker than a phone can be turned over and costs little.
    private let motionUpdateInterval: TimeInterval = 0.1

    private var isMonitoring = false
    private var orientationObserver: NSObjectProtocol?

    public init() {}

    /// Starts watching the phone's attitude. `handler` runs when the phone comes back
    /// upright after the trick is armed.
    public func startMonitoring(handler: @escaping () -> Void) {
        guard !isMonitoring else {
            debugLog("🎭 Plus Perfect: monitoring already running")
            return
        }
        isMonitoring = true
        hapticGenerator.prepare()
        if motionManager.isDeviceMotionAvailable {
            debugLog("🎭 Plus Perfect: watching gravity for the turn")
            startDeviceMotion(handler: handler)
        } else {
            debugLog("⚠️ Plus Perfect: no device motion, falling back to coarse orientation. "
                + "Expect this in the simulator, where a tilted phone cannot be detected.")
            startOrientationNotifications(handler: handler)
        }
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        motionManager.stopDeviceMotionUpdates()
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
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
    public func calculatePerfectAddend(state: inout CalculatorState, force: ForceValues) {
        let forceNumber = Double(force.number)
        let perfectAddend = PlusPerfectMath.perfectAddend(
            savedNumber: savedNumber,
            forceNumber: forceNumber
        )
        state.display = CalculatorFormatter.formatResult(perfectAddend)
        state.operation = .add
        state.previousNumber = savedNumber
        state.currentNumber = perfectAddend
        state.userIsTyping = false
        mode = .calculated
        debugLog("🎭 Plus Perfect: addend \(perfectAddend) for force \(forceNumber)")
    }

    // MARK: - Attitude

    private func startDeviceMotion(handler: @escaping () -> Void) {
        motionManager.deviceMotionUpdateInterval = motionUpdateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let position = PlusPerfectMath.planePosition(
                gravityX: motion.gravity.x,
                gravityY: motion.gravity.y
            )
            self?.apply(position, handler: handler)
        }
    }

    private func startOrientationNotifications(handler: @escaping () -> Void) {
        // Orientation only reports a real value once notifications are being generated.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let position = PlusPerfectMath.planePosition(UIDevice.current.orientation)
            self?.apply(position, handler: handler)
        }
    }

    /// A phone too near level to read is left alone rather than acted on, so whatever was
    /// last seen still stands and setting the phone down cannot give the reveal away.
    private func apply(_ position: PlanePosition?, handler: () -> Void) {
        guard let position else { return }
        if PlusPerfectMath.shouldArm(mode: mode, position: position) {
            arm()
            return
        }
        guard PlusPerfectMath.shouldReveal(mode: mode, position: position) else { return }
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
