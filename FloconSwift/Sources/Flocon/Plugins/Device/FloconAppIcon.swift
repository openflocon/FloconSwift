import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Équivalent de getAppIconBase64 : icône redimensionnée à 300 px max, PNG, base64 sans retour à la ligne.
enum FloconAppIcon {
    private static let maxSize: CGFloat = 300

    @MainActor
    static func base64PNG() -> String? {
        #if canImport(UIKit)
        guard let image = appIcon() else { return nil }
        // en pixels : AppIcon60x60 fait 60 pt mais 120 px en @2x
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
    /// L'icône n'est pas accessible directement sur iOS : on la retrouve via l'Info.plist
    /// (CFBundleIcons, généré par l'asset catalog). On garde la plus grande trouvée.
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
