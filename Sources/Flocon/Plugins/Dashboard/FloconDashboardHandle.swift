import Combine
import Foundation

/// Keeps a dashboard up to date with its publishers.
///
/// The dashboard stops updating when ``cancel()`` is called or when the handle is released:
/// keep it as long as the dashboard should follow the data of the app. A dashboard made
/// of static sections only does not need it.
public final class FloconDashboardHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var cancellable: AnyCancellable?

    init(_ cancellable: AnyCancellable?) {
        self.cancellable = cancellable
    }

    /// Stops updating the dashboard. The desktop app keeps showing its last state.
    public func cancel() {
        lock.lock()
        let cancellable = cancellable
        self.cancellable = nil
        lock.unlock()
        cancellable?.cancel()
    }
}
