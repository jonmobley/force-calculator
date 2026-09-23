import Foundation
import UIKit
import CoreMotion
import Combine

/// Drives Perfect Plus from the phone's physical attitude. Plus is pressed with the phone
/// upright, then turning it over arms the trick and stages the addend behind the turn.
///
/// Gravity is read directly rather than through `UIDevice.orientation`, because that
/// reports `faceUp` as soon as the screen tilts toward horizontal and so cannot say which
/// way round a phone being held out for someone to tap is.
public class PerfectPlusHandler: ObservableObject {
    private let haptics = PerfectPlusHaptics()
    private let motionManager = CMMotionManager()
    @Published public var mode: PerfectPlusState = .inactive
    public var savedNumber: Double = 0

    /// How long the phone must go untouched, once armed, before the addend is staged.
    ///
    /// The number used to wait for the phone to be turned back, which left a visible pause
    /// between the turn and the number landing. Staging it while the screen is still hidden
    /// means the display is already right the moment the phone comes over. Touches are what
    /// the wait watches: a hand wrapped round the glass is exactly where stray presses land,
    /// and each one starts the wait again, so nothing is staged while the phone is still
    /// being handled.
    public static let idleRevealDelay: TimeInterval = 1

    /// 10Hz is far quicker than a phone can be turned over and costs little.
    private let motionUpdateInterval: TimeInterval = 0.1

    private var isMonitoring = false
    private var orientationObserver: NSObjectProtocol?

    /// Run when the addend should go on the display, held here because the wait after the
    /// last touch fires it as well as the turn does.
    private var revealHandler: (() -> Void)?

    private var idleReveal: DispatchWorkItem?

    /// Whether the phone is still turned away from the performer, which decides whether a
    /// reveal leaves the keys inert or hands them back.
    private var phoneIsTurned = false

    /// Last position written to the log. Gravity arrives ten times a second, so only changes
    /// are traced rather than every sample.
    private var lastTracedPosition: String?

    /// Consecutive samples the phone must hold a position before it is acted on, at 10Hz so
    /// half a second. Two reasons: the direction of a near-level phone drifts and would
    /// otherwise wander past the upside-down mark and arm on its own, and a turn onto the
    /// phone's face passes through a half-turn in the plane on the way, so only where the
    /// phone comes to rest should count.
    let dwellSamples = 5

    private var candidateSituation: Situation?
    private var candidateSamples = 0

    /// Which move armed the trick, so the keys come back only when that same move is undone.
    private var armedBy: TurnTrigger?

    /// The force as it stood when the addend was worked out. Date and Time mode reads the
    /// clock live, so equals has to land on this rather than on a fresh reading: a minute
    /// ticking over in between would leave the sum on screen not adding up.
    public private(set) var frozenForce: ForceValues?

    /// What the phone is doing, as far as the trick cares.
    ///
    /// Visible inside the module so tests can drive the state machine directly. Motion
    /// cannot be simulated, and this is the part of the trick that decides whether it
    /// arms, so it needs to be reachable without a physical turn of a phone.
    enum Situation: Equatable {
        case turned(TurnTrigger)
        case returned
        case between
    }

    public init() {}

    /// Starts watching the phone's attitude. `handler` runs when the addend should go on the
    /// display, which is once the armed phone has been left alone for `idleRevealDelay`, or
    /// on the way back if it is turned over again before then.
    public func startMonitoring(hapticsEnabled: Bool, handler: @escaping () -> Void) {
        guard !isMonitoring else {
            debugLog("🎭 Perfect Plus: monitoring already running")
            return
        }
        isMonitoring = true
        revealHandler = handler
        haptics.isEnabled = hapticsEnabled
        haptics.prepare()
        if motionManager.isDeviceMotionAvailable {
            debugLog("🎭 Perfect Plus: watching gravity for the turn, vibration "
                + (hapticsEnabled ? "on" : "off"))
            startDeviceMotion()
        } else {
            debugLog("⚠️ Perfect Plus: no device motion, falling back to coarse orientation. "
                + "Expect this in the simulator, where a tilted phone cannot be detected.")
            startOrientationNotifications()
        }
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        cancelIdleReveal()
        forgetDwell()
        revealHandler = nil
        motionManager.stopDeviceMotionUpdates()
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
            orientationObserver = nil
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    /// Whether the trick buzzes at all. Settable after monitoring has begun because the App
    /// Clip fetches the performer's settings while the calculator is already on screen.
    public var hapticsEnabled: Bool {
        get { haptics.isEnabled }
        set { haptics.isEnabled = newValue }
    }

    /// Reports a touch anywhere on the calculator, so the wait before the addend is staged
    /// starts again. The views call this for every touch, including the ones the inert
    /// keypad swallows, because those are the ones a hand round the glass produces.
    public func noteScreenTouch() {
        guard mode == .armed else { return }
        scheduleIdleReveal()
    }

    /// Records the plus so a later turn of the phone can arm the trick. The addition
    /// itself proceeds as normal, so an unflipped plus behaves like any other calculator.
    public func markPendingAdd(operand: Double) {
        savedNumber = operand
        mode = .pendingAdd
        forgetDwell()
        debugLog("🎭 Perfect Plus: plus pending on \(operand), now waiting for the turn")
    }

    /// Drops any pending or armed trick. Called when the performer does something
    /// that ends the addition, such as equals, clear, or a different operation.
    public func reset() {
        if mode != .inactive {
            debugLog("🎭 Perfect Plus: stood down from \(mode)")
        }
        cancelIdleReveal()
        forgetDwell()
        mode = .inactive
        savedNumber = 0
        armedBy = nil
        phoneIsTurned = false
        frozenForce = nil
    }

    /// Drops the samples counted towards the current position.
    ///
    /// Without this a trick stood down while the phone was face down left a full count
    /// behind, and the next plus armed on the very first sample afterwards, with no turn
    /// of the phone at all. Every stand-down and every fresh plus starts the count again.
    private func forgetDwell() {
        candidateSituation = nil
        candidateSamples = 0
    }

    /// Shows the addend that reaches the force number, ready for equals.
    ///
    /// Staged behind the turn the keys stay inert, because the display now holds the whole
    /// trick and the phone is still in a hand. Turning it back hands them over.
    public func calculatePerfectAddend(state: inout CalculatorState, force: ForceValues) {
        frozenForce = force
        let forceNumber = Double(force.number)
        let perfectAddend = PerfectPlusMath.perfectAddend(
            savedNumber: savedNumber,
            forceNumber: forceNumber
        )
        state.display = CalculatorFormatter.formatResult(perfectAddend)
        state.operation = .add
        state.previousNumber = savedNumber
        state.currentNumber = perfectAddend
        state.userIsTyping = false
        mode = phoneIsTurned ? .staged : .calculated
        debugLog("🎭 Perfect Plus: addend \(perfectAddend) for force \(forceNumber), now \(mode)")
    }

    // MARK: - Attitude

    private func startDeviceMotion() {
        motionManager.deviceMotionUpdateInterval = motionUpdateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            if let error {
                debugLog("⚠️ Perfect Plus: device motion failed — \(error.localizedDescription)")
                return
            }
            guard let self, let motion else { return }
            let reading = PerfectPlusMath.planeReading(
                gravityX: motion.gravity.x,
                gravityY: motion.gravity.y
            )
            let face = PerfectPlusMath.screenFace(gravityZ: motion.gravity.z)
            let current = situation(position: reading.position, face: face)
            trace(reading, face: face, situation: current)
            if let settled = settled(current) {
                act(on: settled)
            }
        }
    }

    private func situation(position: PlanePosition?, face: ScreenFace?) -> Situation {
        if let trigger = PerfectPlusMath.turnTrigger(position: position, face: face) {
            return .turned(trigger)
        }
        if let armedBy,
           PerfectPlusMath.hasReturned(from: armedBy, position: position, face: face) {
            return .returned
        }
        return .between
    }

    /// Passes a situation on only once it has held for `dwellSamples`, so nothing acts on a
    /// single stray sample or on a state merely passed through.
    func settled(_ situation: Situation) -> Situation? {
        if situation == candidateSituation {
            candidateSamples += 1
        } else {
            candidateSituation = situation
            candidateSamples = 1
        }
        return candidateSamples >= dwellSamples ? situation : nil
    }

    private func startOrientationNotifications() {
        // Orientation only reports a real value once notifications are being generated.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let orientation = UIDevice.current.orientation
            let current = situation(
                position: PerfectPlusMath.planePosition(orientation),
                face: PerfectPlusMath.screenFace(orientation)
            )
            let label = "\(current)"
            if label != lastTracedPosition {
                lastTracedPosition = label
                debugLog("🎭 Perfect Plus: \(label) from coarse orientation, mode \(mode)")
            }
            // Notifications already arrive only on a settled change, so no dwell here.
            act(on: current)
        }
    }

    /// Traces each change in how the phone is being held, with the numbers behind it, so a
    /// turn that did not arm can be told from one that was never seen.
    private func trace(_ reading: PlaneReading, face: ScreenFace?, situation: Situation) {
        let label = "\(situation) / face \(face.map { "\($0)" } ?? "on edge")"
        guard label != lastTracedPosition else { return }
        lastTracedPosition = label
        let numbers = String(
            format: "%.0f° from upright, %.2f in plane",
            reading.degreesFromUpright,
            reading.inPlaneGravity
        )
        debugLog("🎭 Perfect Plus: \(label) — \(numbers), mode \(mode)")
    }

    func act(on situation: Situation) {
        switch (mode, situation) {
        case (.pendingAdd, .turned(let trigger)):
            arm(by: trigger)
        case (.armed, .turned(let settled)), (.staged, .turned(let settled)):
            reattribute(to: settled)
        case (.armed, .returned):
            // Brought back before the phone was ever left alone, so the number goes up now.
            debugLog("🎭 Perfect Plus: back from \(turnDescription) before the wait, revealing")
            cancelIdleReveal()
            phoneIsTurned = false
            haptics.playReveal()
            revealHandler?()
        case (.staged, .returned):
            debugLog("🎭 Perfect Plus: back from \(turnDescription) with the number already up")
            phoneIsTurned = false
            mode = .calculated
        default:
            break
        }
    }

    private var turnDescription: String {
        armedBy.map { "\($0)" } ?? "the turn"
    }

    /// Corrects which move is credited with arming, once the phone comes to rest on its face
    /// having armed on the half-turn it swept through getting there.
    private func reattribute(to settled: TurnTrigger) {
        guard let armedBy,
              PerfectPlusMath.shouldReattribute(armedBy: armedBy, settled: settled) else { return }
        debugLog("🎭 Perfect Plus: settled onto its face, the reveal will mirror that instead")
        self.armedBy = settled
    }

    private func arm(by trigger: TurnTrigger) {
        mode = .armed
        armedBy = trigger
        phoneIsTurned = true
        debugLog("🎭 Perfect Plus: armed by \(trigger) holding \(savedNumber)")
        haptics.playArmed()
        scheduleIdleReveal()
    }

    // MARK: - Staging the reveal

    private func scheduleIdleReveal() {
        idleReveal?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.stageReveal()
        }
        idleReveal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleRevealDelay, execute: work)
    }

    private func cancelIdleReveal() {
        idleReveal?.cancel()
        idleReveal = nil
    }

    /// Puts the addend up while the screen is still turned away, so the phone can be brought
    /// back to a display that is already right.
    private func stageReveal() {
        guard mode == .armed else { return }
        idleReveal = nil
        debugLog("🎭 Perfect Plus: untouched for \(Self.idleRevealDelay)s, staging the number")
        haptics.playReveal()
        revealHandler?()
    }
}
