import Foundation

/// A deeplink of the app, listed in the Deeplinks section of the Flocon desktop app.
///
/// Write the parts to fill in between brackets, and describe them with ``parameters``:
///
/// ```swift
/// FloconDeeplink(
///     "[host]://user/[userId]",
///     label: "User",
///     parameters: [
///         .variable("host", variableName: "host"),
///         .autoComplete("userId", ["Florent", "David"]),
///         .autoComplete("tab") { suggestions in
///             suggestions.suggest("friends", label: "Friends list")
///             suggestions.suggestDefault("posts")
///         },
///     ]
/// )
/// ```
public struct FloconDeeplink: Sendable, Equatable {
    /// A part of the link to fill in, written `[name]` in the link.
    public enum Parameter: Sendable, Equatable {
        /// A part filled in from a list of suggestions.
        case autoComplete(_ name: String, _ suggestions: [String])
        /// A part filled in from suggestions that can have a label and a default one, see
        /// ``autoComplete(_:suggestions:)`` to build them.
        case suggestions(_ name: String, _ suggestions: [FloconDeeplinkSuggestion])
        /// A part filled in with the value of a ``FloconDeeplinkVariable``, shared by several deeplinks.
        case variable(_ name: String, variableName: String)

        /// A part filled in from suggestions that can have a label, and a default one that the
        /// desktop app pre-selects.
        ///
        /// - Parameters:
        ///   - name: Name of the part, written `[name]` in the link.
        ///   - build: Declares the suggestions.
        public static func autoComplete(
            _ name: String,
            suggestions build: (inout FloconDeeplinkSuggestions) -> Void
        ) -> Parameter {
            var suggestions = FloconDeeplinkSuggestions()
            build(&suggestions)
            return .suggestions(name, suggestions.suggestions)
        }
    }

    /// The link, with its parameters between brackets.
    public let link: String
    /// Short name shown instead of the link.
    public let label: String?
    /// What the deeplink opens.
    public let description: String?
    /// The parts of the link to fill in.
    public let parameters: [Parameter]

    /// Creates a deeplink.
    ///
    /// - Parameters:
    ///   - link: The link, with its parameters between brackets, for example `myapp://user/[userId]`.
    ///   - label: Short name shown instead of the link.
    ///   - description: What the deeplink opens.
    ///   - parameters: The parts of the link to fill in.
    public init(_ link: String, label: String? = nil, description: String? = nil, parameters: [Parameter] = []) {
        self.link = link
        self.label = label
        self.description = description
        self.parameters = parameters
    }
}

/// A value shared by several deeplinks, such as the URL scheme or a host, edited once in the desktop app.
public struct FloconDeeplinkVariable: Sendable, Equatable {
    /// Name of the variable, referenced by ``FloconDeeplink/Parameter/variable(_:variableName:)``.
    public let name: String
    /// What the variable is for.
    public let description: String?
    /// Values offered in the desktop app, or `nil` for a free text input.
    public let suggestions: [String]?
    /// Suggestions with their label and default, or `nil` when the variable was created with plain values.
    public let suggestionItems: [FloconDeeplinkSuggestion]?

    /// Creates a variable.
    ///
    /// - Parameters:
    ///   - name: Name of the variable.
    ///   - description: What the variable is for.
    ///   - suggestions: Values offered in the desktop app. Defaults to `nil`, a free text input.
    public init(_ name: String, description: String? = nil, suggestions: [String]? = nil) {
        self.name = name
        self.description = description
        self.suggestions = suggestions
        self.suggestionItems = nil
    }

    /// Creates a variable whose suggestions can have a label, and a default one that the desktop app pre-selects.
    ///
    /// - Parameters:
    ///   - name: Name of the variable.
    ///   - description: What the variable is for.
    ///   - build: Declares the suggestions.
    public init(
        _ name: String,
        description: String? = nil,
        suggestions build: (inout FloconDeeplinkSuggestions) -> Void
    ) {
        var collected = FloconDeeplinkSuggestions()
        build(&collected)
        let items = collected.suggestions
        self.name = name
        self.description = description
        self.suggestions = items.map(\.value)
        self.suggestionItems = items
    }
}
