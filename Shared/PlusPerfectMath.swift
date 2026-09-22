import Foundation

/// Pure Plus Perfect decisions shared by the host and the App Clip.
public enum PlusPerfectMath {
    /// Addend that makes `savedNumber + addend` equal `forceNumber`.
    public static func perfectAddend(savedNumber: Double, forceNumber: Double) -> Double {
        forceNumber - savedNumber
    }

    /// Upside-down plus arms the trick. Upright plus stays normal addition.
    public static func shouldArm(
        plusPerfectEnabled: Bool,
        isAdd: Bool,
        isUpsideDown: Bool
    ) -> Bool {
        plusPerfectEnabled && isAdd && isUpsideDown
    }
}
