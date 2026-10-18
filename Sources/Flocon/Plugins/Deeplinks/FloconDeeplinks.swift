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
///     ]
/// )
/// ```
public struct FloconDeeplink: Sendable, Equatable {
    /// A part of the link to fill in, written `[name]` in the link.
    public enum Parameter: Sendable, Equatable {
        /// A part filled in from a list of suggestions.
        case autoComplete(_ name: String, _ suggestions: [String])
        /// A part filled in with the value of a ``FloconDeeplinkVariable``, shared by several deeplinks.
        case variable(_ name: String, variableName: String)
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
    }
}

/// Lists the deeplinks of the app in the Deeplinks section of the Flocon desktop app.
///
/// ```swift
/// floconRegisterDeeplinks(
///     [
///         FloconDeeplink("myapp://home", label: "Home"),
///         FloconDeeplink(
///             "myapp://user/[userId]",
///             label: "User",
///             parameters: [.autoComplete("userId", ["Florent", "David"])]
///         ),
///     ],
///     variables: [FloconDeeplinkVariable("env", suggestions: ["staging", "production"])]
/// )
/// ```
///
/// Calling this function again replaces the list. The list is sent again on each connection.
/// Does nothing if ``Flocon/initialize(config:)`` has not been called.
///
/// - Parameters:
///   - deeplinks: The deeplinks of the app.
///   - variables: The variables referenced by the deeplinks. Defaults to none.
public func floconRegisterDeeplinks(_ deeplinks: [FloconDeeplink], variables: [FloconDeeplinkVariable] = []) {
    Flocon.shared.client?.deeplinksPlugin?.register(deeplinks: deeplinks, variables: variables)
}

extension Flocon {
    /// Lists the deeplinks of the app in the Flocon desktop app.
    ///
    /// See ``floconRegisterDeeplinks(_:variables:)``.
    ///
    /// - Parameters:
    ///   - deeplinks: The deeplinks of the app.
    ///   - variables: The variables referenced by the deeplinks.
    public static func registerDeeplinks(_ deeplinks: [FloconDeeplink], variables: [FloconDeeplinkVariable] = []) {
        floconRegisterDeeplinks(deeplinks, variables: variables)
    }
}
