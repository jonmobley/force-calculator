import Foundation
import UIKit

/// How the phone is rotated within its own plane, independent of how far it is tilted
/// toward horizontal. A phone presented almost flat for someone to tap still reads as
/// upright or upside down.
public enum PlanePosition {
    case upright
    case upsideDown
    case sideways
}

/// Which way the screen is pointing, read from the axis out of the screen. Turning the phone
/// onto its face is the move that hides the inert keypad, and it is the one signal gravity
/// gives unambiguously: the axis swings from about -1 face-up to about +1 face-down.
public enum ScreenFace {
    case up
    case down
}

/// The move that turned the phone over, so the reveal can wait for that same move to be
/// undone rather than for any change at all.
public enum TurnTrigger: CustomStringConvertible {
    /// Turned onto its face, hiding the screen.
    case faceDown
    /// Kept screen-up and rotated half a turn in its own plane.
    case planeRotation

    public var description: String {
        switch self {
        case .faceDown:
            return "face down"
        case .planeRotation:
            return "half turn"
        }
    }
}

/// One gravity sample resolved into a position, keeping the numbers behind the verdict so a
/// turn that failed to register can be told apart from one that was never seen.
public struct PlaneReading {
    public let position: PlanePosition?
    /// Share of gravity lying in the screen plane. Below `minimumInPlaneGravity` its
    /// direction is noise and `position` is nil.
    public let inPlaneGravity: Double
    /// Rotation away from upright, 0 through 180. Meaningless once `position` is nil.
    public let degreesFromUpright: Double
}

/// Pure Perfect Plus decisions shared by the host and the App Clip.
public enum PerfectPlusMath {
    /// Smallest share of gravity that must lie in the screen plane before its direction
    /// means anything. 0.12 is roughly 7 degrees off flat.
    ///
    /// Measured against a phone turned on a table: the deliberate turn held 0.19 to 0.21
    /// while the same phone at rest wandered between 0.03 and 0.05, its direction drifting
    /// as far as 167 degrees on noise alone. The gate sits between those two, low enough to
    /// read a turn performed almost flat and high enough that a resting phone cannot arm.
    public static let minimumInPlaneGravity = 0.12

    /// Degrees from upright still counted as upright.
    public static let uprightLimit: Double = 60

    /// Degrees from upright needed to count as upside down. The gap between the two
    /// limits is a dead zone, so a wobble near the boundary cannot flip the answer back
    /// and forth.
    public static let upsideDownLimit: Double = 120

    /// Addend that makes `savedNumber + addend` equal `forceNumber`.
    public static func perfectAddend(savedNumber: Double, forceNumber: Double) -> Double {
        forceNumber - savedNumber
    }

    /// Plus leaves the trick waiting, so it can be pressed with the phone still upright.
    /// Any other operation clears that wait.
    public static func shouldMarkPendingAdd(perfectPlusEnabled: Bool, isAdd: Bool) -> Bool {
        perfectPlusEnabled && isAdd
    }

    /// Past this much of gravity along the screen axis the phone is face-down. Set higher
    /// than the face-up limit so the two leave a dead band between them, which a phone held
    /// on edge falls into rather than flickering between both.
    public static let faceDownGravity = 0.5

    /// Below this the phone is face-up. Loose enough that bringing it back to a normal
    /// reading angle still counts as having returned, rather than demanding it lie flat.
    public static let faceUpGravity = -0.4

    public static func screenFace(gravityZ: Double) -> ScreenFace? {
        if gravityZ >= faceDownGravity { return .down }
        if gravityZ <= faceUpGravity { return .up }
        return nil
    }

    /// Coarse fallback, for devices without device motion.
    public static func screenFace(_ orientation: UIDeviceOrientation) -> ScreenFace? {
        switch orientation {
        case .faceUp:
            return .up
        case .faceDown:
            return .down
        default:
            return nil
        }
    }

    /// Which turn, if any, the phone is currently in. Face-down wins, because a phone on its
    /// face is unambiguous whereas the in-plane angle of a nearly level phone is marginal.
    public static func turnTrigger(position: PlanePosition?, face: ScreenFace?) -> TurnTrigger? {
        if face == .down { return .faceDown }
        if position == .upsideDown { return .planeRotation }
        return nil
    }

    /// Whether a newly settled turn should replace the one recorded as having armed the trick.
    ///
    /// Only a turn onto the face may replace a reading of the plane, never the reverse. A
    /// phone being turned onto its face sweeps through a half-turn in the plane on the way, so
    /// the plane can arm first and needs correcting once the phone comes to rest. The same
    /// sweep happens in reverse while it is turned back, and honouring that would strand the
    /// reveal waiting for an upright position that never comes.
    public static func shouldReattribute(armedBy: TurnTrigger, settled: TurnTrigger) -> Bool {
        armedBy == .planeRotation && settled == .faceDown
    }

    /// Whether the phone has undone the move that armed it. Each move is mirrored by its own
    /// opposite, so a turn onto its face is not answered by a half-turn in the plane.
    public static func hasReturned(
        from trigger: TurnTrigger,
        position: PlanePosition?,
        face: ScreenFace?
    ) -> Bool {
        switch trigger {
        case .faceDown:
            return face == .up
        case .planeRotation:
            return position == .upright
        }
    }

    /// Reads the phone's in-plane rotation from the gravity vector, in device coordinates
    /// where `y` runs toward the top of the screen. Tilt toward horizontal only shrinks
    /// the in-plane component, so a phone held out at a shallow angle still reports which
    /// way round it is. Returns `nil` when the phone is too near level to tell, letting
    /// the caller keep whatever it last saw.
    public static func planePosition(gravityX: Double, gravityY: Double) -> PlanePosition? {
        planeReading(gravityX: gravityX, gravityY: gravityY).position
    }

    /// As `planePosition`, but also reports the two numbers the verdict rests on so they can
    /// be traced.
    public static func planeReading(gravityX: Double, gravityY: Double) -> PlaneReading {
        let inPlane = (gravityX * gravityX + gravityY * gravityY).squareRoot()
        let degrees = abs(atan2(gravityX, -gravityY)) * 180 / .pi
        guard inPlane >= minimumInPlaneGravity else {
            return PlaneReading(position: nil, inPlaneGravity: inPlane, degreesFromUpright: degrees)
        }
        let position: PlanePosition
        if degrees <= uprightLimit {
            position = .upright
        } else if degrees >= upsideDownLimit {
            position = .upsideDown
        } else {
            position = .sideways
        }
        return PlaneReading(position: position, inPlaneGravity: inPlane, degreesFromUpright: degrees)
    }

    /// Coarse fallback for devices without device motion, such as the simulator. This
    /// cannot describe a tilted phone, because `faceUp` and `faceDown` carry no
    /// information about which way round the phone is.
    public static func planePosition(_ orientation: UIDeviceOrientation) -> PlanePosition? {
        switch orientation {
        case .portrait:
            return .upright
        case .portraitUpsideDown:
            return .upsideDown
        case .landscapeLeft, .landscapeRight:
            return .sideways
        default:
            return nil
        }
    }
}
