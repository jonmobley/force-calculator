import AppKit
import CoreGraphics

// Two small helpers for driving the iOS Simulator from the shell.
//
//   simclick calibrate <capture.png> <winX> <winY> <winW> <winH>
//       Finds the device screen rect inside a capture of the Simulator window and
//       prints it as "x y w h" in global screen points.
//
//   simclick tap <screenX> <screenY> <screenW> <screenH> <devW> <devH> <xPt> <yPt> [hold]
//       Clicks at a coordinate given in device points.
//
// Capture is left to the caller because screencapture needs a screen-recording grant
// that the terminal has and a freshly built binary does not.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 2 else { fail("usage: simclick <calibrate|tap> ...") }

switch args[1] {
case "calibrate":
    guard args.count >= 7,
          let winX = Double(args[3]), let winY = Double(args[4]),
          let winW = Double(args[5]), let winH = Double(args[6]) else {
        fail("usage: simclick calibrate <capture.png> <winX> <winY> <winW> <winH>")
    }
    guard let source = CGImageSourceCreateWithURL(
        URL(fileURLWithPath: args[2]) as CFURL, nil
    ), let shot = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("cannot read capture at \(args[2])")
    }
    guard let data = shot.dataProvider?.data, let pixels = CFDataGetBytePtr(data) else {
        fail("cannot read capture pixels")
    }
    let width = shot.width
    let height = shot.height
    let bytesPerRow = shot.bytesPerRow
    let bytesPerPixel = shot.bitsPerPixel / 8

    /// Clearly lit, as opposed to the near-black bezel, title bar, and window shadow.
    func isBright(_ x: Int, _ y: Int) -> Bool {
        let offset = y * bytesPerRow + x * bytesPerPixel
        return Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2]) > 400
    }

    // Edge-walking from the window border fails here: the rounded corners let the
    // desktop show through, the title bar is not quite black, and the Dynamic Island
    // is a dark island in the middle of a light screen. Counting bright pixels per row
    // and per column instead finds the screen as the band that is mostly lit, which no
    // single stray feature can move. Calibrate while a light screen is showing.
    var rowBright = [Int](repeating: 0, count: height)
    var brightestRow = 0
    for y in 0..<height {
        var count = 0
        for x in stride(from: 0, to: width, by: 2) where isBright(x, y) { count += 1 }
        rowBright[y] = count * 2
        brightestRow = max(brightestRow, rowBright[y])
    }
    /// The screen is the lit band through the middle of the window. Taking the run that
    /// contains the centre discards the slivers of desktop visible through the window's
    /// transparent margins, which are lit too but are not part of the device.
    func runContainingCentre(_ counts: [Int], threshold: Int, centre: Int) -> (Int, Int)? {
        guard counts.indices.contains(centre), counts[centre] >= threshold else { return nil }
        var start = centre
        while start > 0, counts[start - 1] >= threshold { start -= 1 }
        var end = centre
        while end < counts.count - 1, counts[end + 1] >= threshold { end += 1 }
        return (start, end)
    }

    // A quarter of the widest lit row, not half: the screen's corners are rounded, so its
    // first and last rows are only partly lit and a stricter threshold clips them off,
    // which shortens the screen and skews every tap below the middle.
    let rowThreshold = max(width / 8, brightestRow / 4)
    guard let (top, bottom) = runContainingCentre(
        rowBright, threshold: rowThreshold, centre: height / 2
    ) else { fail("no lit band found; calibrate while a light screen is showing") }

    let span = bottom - top + 1
    var colBright = [Int](repeating: 0, count: width)
    var brightestCol = 0
    for x in 0..<width {
        var count = 0
        for y in stride(from: top, through: bottom, by: 2) where isBright(x, y) { count += 1 }
        colBright[x] = count * 2
        brightestCol = max(brightestCol, colBright[x])
    }
    let colThreshold = max(span / 2, brightestCol / 2)
    guard let (left, right) = runContainingCentre(
        colBright, threshold: colThreshold, centre: width / 2
    ) else { fail("no lit columns found") }

    guard right - left > 50, bottom - top > 50 else { fail("screen rect not found") }

    let pixelsPerPoint = Double(width) / winW
    _ = winH
    let x = winX + Double(left) / pixelsPerPoint
    let y = winY + Double(top) / pixelsPerPoint
    let w = Double(right - left + 1) / pixelsPerPoint
    let h = Double(bottom - top + 1) / pixelsPerPoint
    print(String(format: "%.2f %.2f %.2f %.2f", x, y, w, h))

case "tap":
    guard args.count >= 10,
          let screenX = Double(args[2]), let screenY = Double(args[3]),
          let screenW = Double(args[4]), let screenH = Double(args[5]),
          let devW = Double(args[6]), let devH = Double(args[7]),
          let xPt = Double(args[8]), let yPt = Double(args[9]) else {
        fail("usage: simclick tap <sx> <sy> <sw> <sh> <devW> <devH> <xPt> <yPt> [hold]")
    }
    let hold = args.count > 10 ? (Double(args[10]) ?? 0) : 0
    let point = CGPoint(
        x: screenX + xPt * (screenW / devW),
        y: screenY + yPt * (screenH / devH)
    )
    let source = CGEventSource(stateID: .hidSystemState)
    CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
            mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(80_000)
    CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
            mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(hold > 0 ? useconds_t(hold * 1_000_000) : 50_000)
    CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
            mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)

case "drag":
    // Dragging rather than scroll-wheel events: the Simulator turns a real press-move-release
    // into a touch drag, which is what a SwiftUI scroll view responds to.
    guard args.count >= 12,
          let screenX = Double(args[2]), let screenY = Double(args[3]),
          let screenW = Double(args[4]), let screenH = Double(args[5]),
          let devW = Double(args[6]), let devH = Double(args[7]),
          let fromX = Double(args[8]), let fromY = Double(args[9]),
          let toX = Double(args[10]), let toY = Double(args[11]) else {
        fail("usage: simclick drag <sx> <sy> <sw> <sh> <devW> <devH> <x1> <y1> <x2> <y2>")
    }
    let scaleX = screenW / devW
    let scaleY = screenH / devH
    func screenPoint(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: screenX + x * scaleX, y: screenY + y * scaleY)
    }
    let start = screenPoint(fromX, fromY)
    let end = screenPoint(toX, toY)
    let source = CGEventSource(stateID: .hidSystemState)
    CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
            mouseCursorPosition: start, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(80_000)
    CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
            mouseCursorPosition: start, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(80_000)
    let steps = 28
    for step in 1...steps {
        let progress = Double(step) / Double(steps)
        let point = CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
        CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged,
                mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(9_000)
    }
    // Held still before release so the scroll settles instead of flinging.
    usleep(220_000)
    CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
            mouseCursorPosition: end, mouseButton: .left)?.post(tap: .cghidEventTap)

case "scroll":
    // Scroll wheel events rather than a synthetic touch drag: the Simulator maps these
    // to a trackpad scroll, which SwiftUI's scroll views pick up reliably. A dragged
    // mouse is delivered as a single touch and a form often just ignores it.
    guard args.count >= 10,
          let screenX = Double(args[2]), let screenY = Double(args[3]),
          let screenW = Double(args[4]), let screenH = Double(args[5]),
          let devW = Double(args[6]), let devH = Double(args[7]),
          let xPt = Double(args[8]), let yPt = Double(args[9]) else {
        fail("usage: simclick scroll <sx> <sy> <sw> <sh> <devW> <devH> <xPt> <yPt> [lines]")
    }
    let lines = args.count > 10 ? (Int(args[10]) ?? -10) : -10
    let point = CGPoint(
        x: screenX + xPt * (screenW / devW),
        y: screenY + yPt * (screenH / devH)
    )
    let source = CGEventSource(stateID: .hidSystemState)
    CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
            mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(80_000)
    // Delivered in small steps so it reads as a flick rather than one huge jump.
    let steps = 12
    for _ in 0..<steps {
        guard let wheel = CGEvent(
            scrollWheelEvent2Source: source,
            units: .line,
            wheelCount: 1,
            wheel1: Int32(lines / steps == 0 ? (lines < 0 ? -1 : 1) : lines / steps),
            wheel2: 0,
            wheel3: 0
        ) else { continue }
        wheel.location = point
        wheel.post(tap: .cghidEventTap)
        usleep(25_000)
    }

case "probe":
    guard let source = CGImageSourceCreateWithURL(
        URL(fileURLWithPath: args[2]) as CFURL, nil
    ), let shot = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let data = shot.dataProvider?.data, let pixels = CFDataGetBytePtr(data) else {
        fail("cannot read capture")
    }
    let bytesPerRow = shot.bytesPerRow
    let bytesPerPixel = shot.bitsPerPixel / 8
    print("image \(shot.width)x\(shot.height) bpp=\(shot.bitsPerPixel) row=\(bytesPerRow)")
    func brightness(_ x: Int, _ y: Int) -> Int {
        let offset = y * bytesPerRow + x * bytesPerPixel
        return Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])
    }
    let midY = shot.height / 2
    var row: [String] = []
    for x in stride(from: 0, to: min(120, shot.width), by: 4) {
        row.append("\(x):\(brightness(x, midY))")
    }
    print("row@\(midY) left: " + row.joined(separator: " "))
    let midX = shot.width / 2
    var col: [String] = []
    for y in stride(from: 0, to: min(260, shot.height), by: 8) {
        col.append("\(y):\(brightness(midX, y))")
    }
    print("col@\(midX) top: " + col.joined(separator: " "))

default:
    fail("unknown command '\(args[1])'")
}
