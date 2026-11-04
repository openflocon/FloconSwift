import Flocon
import SwiftUI

/// Logs every screen change in the Flocon timeline, with the screen it comes from.
@MainActor
enum SampleNavigationLog {
    private static var current: String?

    static func screenAppeared(_ name: String) {
        guard name != current else { return }
        var params: [String: String] = [:]
        if let current { params["from"] = current }
        current = name
        Flocon.timelinePlugin.logNavigation(name, params: params)
    }
}

extension View {
    /// Logs a navigation event in the Flocon timeline each time the screen appears.
    ///
    /// - Parameter name: A stable, readable name of the screen.
    func logsNavigation(_ name: String) -> some View {
        onAppear { SampleNavigationLog.screenAppeared(name) }
    }
}
