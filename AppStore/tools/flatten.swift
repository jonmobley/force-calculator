import AppKit
import CoreGraphics
import UniformTypeIdentifiers

// Rewrites PNGs without an alpha channel. App Store Connect rejects screenshots that
// carry one, even when every pixel is fully opaque.

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        FileHandle.standardError.write(Data("skip (unreadable): \(path)\n".utf8))
        continue
    }

    let width = image.width
    let height = image.height
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        FileHandle.standardError.write(Data("skip (no context): \(path)\n".utf8))
        continue
    }

    // Painted onto black so any translucent pixel resolves the way it looked on device.
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let flattened = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
          ) else {
        FileHandle.standardError.write(Data("skip (no output): \(path)\n".utf8))
        continue
    }
    CGImageDestinationAddImage(destination, flattened, nil)
    CGImageDestinationFinalize(destination)
    print("flattened \(width)x\(height) \(url.lastPathComponent)")
}
