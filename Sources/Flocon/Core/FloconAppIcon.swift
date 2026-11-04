import Foundation
#if canImport(UIKit)
import UIKit
import ImageIO
#elseif canImport(AppKit)
import AppKit
#endif

/// Reads the app icon and encodes it for the desktop app.
enum FloconAppIcon {
    private static let maxSize: CGFloat = 300

    /// Returns the app icon as a base64 PNG, at most 300 pixels wide.
    ///
    /// On iOS, the icon is resized and encoded off the main thread, with Core Graphics and
    /// ImageIO. On macOS, AppKit drawing stays on the main actor.
    ///
    /// - Returns: The encoded icon, or `nil` if the app has no icon.
    @concurrent
    static func base64PNG() async -> String? {
        #if canImport(UIKit)
        return uiKitBase64PNG()
        #elseif canImport(AppKit)
        return await MainActor.run { appKitBase64PNG() }
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    /// Resizes with Core Graphics and encodes with ImageIO, which are safe off the main thread.
    private static func uiKitBase64PNG() -> String? {
        guard let cgImage = appIcon()?.cgImage else { return nil }
        // in pixels: AppIcon60x60 is 60 points, but 120 pixels at @2x
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let scale = min(maxSize / pixelWidth, maxSize / pixelHeight, 1)
        let width = Int((pixelWidth * scale).rounded())
        let height = Int((pixelHeight * scale).rounded())
        guard
            width > 0, height > 0,
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let resized = context.makeImage() else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, resized, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return (data as Data).base64EncodedString()
    }
    #elseif canImport(AppKit)
    @MainActor
    private static func appKitBase64PNG() -> String? {
        let image = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        let side = Int(maxSize)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])?.base64EncodedString()
    }
    #endif

    #if canImport(UIKit)
    /// Finds the largest app icon listed in the Info.plist.
    ///
    /// iOS has no API that returns the app icon: its file names are listed under
    /// `CFBundleIcons`, which the asset catalog compiler generates.
    private static func appIcon() -> UIImage? {
        let info = Bundle.main.infoDictionary
        let primary = (info?["CFBundleIcons"] as? [String: Any])?["CFBundlePrimaryIcon"] as? [String: Any]
        var names: [String] = []
        if let name = primary?["CFBundleIconName"] as? String { names.append(name) }
        names += (primary?["CFBundleIconFiles"] as? [String]) ?? []
        return names
            .compactMap { UIImage(named: $0) }
            .max { $0.size.width * $0.scale < $1.size.width * $1.scale }
    }
    #endif
}
