import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Reads the app icon and encodes it for the desktop app.
enum FloconAppIcon {
    private static let maxSize: CGFloat = 300

    /// Returns the app icon as a base64 PNG, at most 300 pixels wide.
    ///
    /// - Returns: The encoded icon, or `nil` if the app has no icon.
    @MainActor
    static func base64PNG() -> String? {
        #if canImport(UIKit)
        guard let image = appIcon() else { return nil }
        // in pixels: AppIcon60x60 is 60 points, but 120 pixels at @2x
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let scale = min(maxSize / pixelWidth, maxSize / pixelHeight, 1)
        let size = CGSize(width: (pixelWidth * scale).rounded(), height: (pixelHeight * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.pngData()?.base64EncodedString()
        #elseif canImport(AppKit)
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
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    /// Finds the largest app icon listed in the Info.plist.
    ///
    /// iOS has no API that returns the app icon: its file names are listed under
    /// `CFBundleIcons`, which the asset catalog compiler generates.
    @MainActor
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
