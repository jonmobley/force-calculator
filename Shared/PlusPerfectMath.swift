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

/// Pure Plus Perfect decisions shared by the host and the App Clip.
public enum PlusPerfectMath {
    /// Smallest share of gravity that must lie in the screen plane before its direction
    /// means anything. 0.2 is roughly 12 degrees off flat; below that the phone is close
    /// enough to level that the reading is mostly noise.
    public static let minimumInPlaneGravity = 0.2

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
    public static func shouldMarkPendingAdd(plusPerfectEnabled: Bool, isAdd: Bool) -> Bool {
        plusPerfectEnabled && isAdd
    }

    /// Turning the phone over arms the trick, but only while a plus is pending. With no
    /// pending plus, the phone can be turned over as much as you like and nothing happens.
    public static func shouldArm(mode: PlusPerfectState, position: PlanePosition) -> Bool {
        mode == .pendingAdd && position == .upsideDown
    }

    /// An armed trick reveals once the phone comes back upright. Sideways on the way
    /// round is ignored, so a slow half turn still lands.
    public static func shouldReveal(mode: PlusPerfectState, position: PlanePosition) -> Bool {
        mode == .armed && position == .upright
    }

    /// Reads the phone's in-plane rotation from the gravity vector, in device coordinates
    /// where `y` runs toward the top of the screen. Tilt toward horizontal only shrinks
    /// the in-plane component, so a phone held out at a shallow angle still reports which
    /// way round it is. Returns `nil` when the phone is too near level to tell, letting
    /// the caller keep whatever it last saw.
    public static func planePosition(gravityX: Double, gravityY: Double) -> PlanePosition? {
        let inPlane = (gravityX * gravityX + gravityY * gravityY).squareRoot()
        guard inPlane >= minimumInPlaneGravity else { return nil }
        let radiansFromUpright = abs(atan2(gravityX, -gravityY))
        let degreesFromUpright = radiansFromUpright * 180 / .pi
        if degreesFromUpright <= uprightLimit { return .upright }
        if degreesFromUpright >= upsideDownLimit { return .upsideDown }
        return .sideways
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
