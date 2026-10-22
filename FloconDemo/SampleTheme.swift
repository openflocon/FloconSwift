import SwiftUI

/// Same tokens as the Flocon Desktop dark theme, so the sample looks like the app it is debugged with.
enum SampleTheme {
    static let bg = Color(hex: 0x111111)
    static let surface = Color(hex: 0x151515)
    static let surfaceHigh = Color(hex: 0x1F1F1F)
    static let surfaceHighest = Color(hex: 0x282828)
    static let line = Color(hex: 0x2A2A2A)
    static let ink = Color(hex: 0xECECEC)
    static let inkMuted = Color(hex: 0xA3A3A3)
    static let inkFaint = Color(hex: 0x828282)
    static let accent = Color(hex: 0xF5B440)
    static let onAccent = Color(hex: 0x1C1405)
    static let success = Color(hex: 0x4FD08A)
    static let warning = Color(hex: 0xF7A531)
    static let error = Color(hex: 0xFF6D6D)
}

/// The color of each family of plugins, used for its icon and its tile.
enum SampleCategory {
    case network, database, analytics, featureFlags, table, deeplink, crash, neutral

    var color: Color {
        switch self {
        case .network: Color(hex: 0x5EAAF7)
        case .database: Color(hex: 0x3FCFB5)
        case .analytics: Color(hex: 0xB494FF)
        case .featureFlags: Color(hex: 0xF5B440)
        case .table: Color(hex: 0xA9D65E)
        case .deeplink: Color(hex: 0xF483C2)
        case .crash: Color(hex: 0xFF6D6D)
        case .neutral: Color(hex: 0xA8ADB6)
        }
    }

    /// Translucent background behind the icon.
    var soft: Color { color.opacity(0.13) }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
