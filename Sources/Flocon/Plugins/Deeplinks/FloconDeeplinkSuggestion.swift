import Foundation

/// A value suggested for a deeplink parameter or variable in the desktop app.
///
/// Give it a ``label`` to show something friendlier than the raw value in the suggestions:
/// the ``value`` is what goes in the link when the suggestion is picked.
public struct FloconDeeplinkSuggestion: Sendable, Equatable {
    /// What is inserted in the link.
    public let value: String
    /// What the desktop app shows instead of the value, or `nil` to show the value.
    public let label: String?
    /// Whether the desktop app pre-selects this suggestion while the field is empty.
    public let isDefault: Bool

    /// Creates a suggestion.
    ///
    /// - Parameters:
    ///   - value: What is inserted in the link.
    ///   - label: What the desktop app shows instead of the value.
    ///   - isDefault: Whether the desktop app pre-selects it while the field is empty.
    public init(_ value: String, label: String? = nil, isDefault: Bool = false) {
        self.value = value
        self.label = label
        self.isDefault = isDefault
    }
}

/// Collects the suggestions of a deeplink parameter or variable, see
/// ``FloconDeeplink/Parameter/autoComplete(_:suggestions:)`` and ``FloconDeeplinkVariable``.
///
/// ```swift
/// .autoComplete("tab") { suggestions in
///     suggestions.suggest("posts")
///     suggestions.suggest("friends", label: "Friends list")
///     suggestions.suggestDefault("all", label: "Everything")
/// }
/// ```
public struct FloconDeeplinkSuggestions: Sendable {
    private var items: [FloconDeeplinkSuggestion] = []

    init() {}

    /// Suggests a value, shown with its label when there is one.
    public mutating func suggest(_ value: String, label: String? = nil) {
        items.append(FloconDeeplinkSuggestion(value, label: label))
    }

    /// Suggests a value, shown with its label when there is one, and pre-selects it while the field is empty.
    public mutating func suggestDefault(_ value: String, label: String? = nil) {
        items.append(FloconDeeplinkSuggestion(value, label: label, isDefault: true))
    }

    /// The suggestions, without duplicated values (the last declaration of a value wins) and with at most one default.
    var suggestions: [FloconDeeplinkSuggestion] {
        FloconDeeplinkSuggestions.normalized(items)
    }

    /// Removes the duplicated values, the last declaration of a value wins, and keeps only the first default.
    static func normalized(_ items: [FloconDeeplinkSuggestion]) -> [FloconDeeplinkSuggestion] {
        var lastIndex: [String: Int] = [:]
        for (index, item) in items.enumerated() {
            lastIndex[item.value] = index
        }
        let unique = items.enumerated().filter { lastIndex[$0.element.value] == $0.offset }.map(\.element)
        let defaultValue = unique.first(where: \.isDefault)?.value
        return unique.map { item in
            FloconDeeplinkSuggestion(
                item.value,
                label: item.label,
                isDefault: defaultValue != nil && item.value == defaultValue
            )
        }
    }
}
