import Foundation

extension FloconFeature where Options == Void {
    /// Sends timeline logs: navigation, user actions, lifecycle and your own events. See ``FloconTimelinePlugin``.
    public static var timeline: FloconFeature<Void> { .init(.timeline) }
}
