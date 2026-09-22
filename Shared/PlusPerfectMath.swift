import Foundation
import UIKit

/// Pure Plus Perfect decisions shared by the host and the App Clip.
public enum PlusPerfectMath {
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
    public static func shouldArm(
        mode: PlusPerfectState,
        heldOrientation: UIDeviceOrientation
    ) -> Bool {
        mode == .pendingAdd && heldOrientation == .portraitUpsideDown
    }

    /// Orientations that describe how the phone is held in a vertical plane.
    /// `faceUp`, `faceDown`, and `unknown` are discarded because a phone resting on a
    /// table reports them no matter which way round it was last held.
    public static func heldOrientation(_ orientation: UIDeviceOrientation) -> UIDeviceOrientation? {
        switch orientation {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return orientation
        default:
            return nil
        }
    }

    /// An armed trick reveals once the phone comes back to upright portrait. Arming
    /// already required an upside-down phone, so landscape on the way round is ignored
    /// and a slow half turn still lands.
    public static func shouldReveal(
        mode: PlusPerfectState,
        heldOrientation: UIDeviceOrientation
    ) -> Bool {
        mode == .armed && heldOrientation == .portrait
    }
}
