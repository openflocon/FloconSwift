import Combine
import Foundation

/// A section or a form of a dashboard, which can update over time.
///
/// Created by ``FloconSection`` and ``FloconForm``, inside ``floconDashboard(id:_:)``.
public struct FloconDashboardContent {
    let publisher: AnyPublisher<FloconDashboardContainer, Never>
}
