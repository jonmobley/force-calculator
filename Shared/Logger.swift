import Foundation

/// Public so the App Clip can log too; the host target has its own copy that
/// shadows this one.
public func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}
