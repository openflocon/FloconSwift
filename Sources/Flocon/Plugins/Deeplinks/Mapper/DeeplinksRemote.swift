#if FloconEnabled
import Foundation

/// JSON format of the deeplinks sent to the desktop app.
///
/// Like the other SDKs, values equal to their default are omitted: a missing label or
/// description, and the `input` mode of a variable.
struct DeeplinksRemote: Encodable {
    let deeplinks: [DeeplinkRemote]
    let variables: [DeeplinkVariableRemote]

    init(deeplinks: [FloconDeeplink], variables: [FloconDeeplinkVariable]) {
        self.deeplinks = deeplinks.map(DeeplinkRemote.init)
        self.variables = variables.map(DeeplinkVariableRemote.init)
    }
}

/// JSON format of a deeplink.
struct DeeplinkRemote: Encodable {
    let label: String?
    let link: String
    let description: String?
    let parameters: [DeeplinkParameterRemote]

    init(_ deeplink: FloconDeeplink) {
        label = deeplink.label
        link = deeplink.link
        description = deeplink.description
        parameters = deeplink.parameters.map(DeeplinkParameterRemote.init)
    }
}

/// JSON format of a deeplink parameter, tagged by `type`.
struct DeeplinkParameterRemote: Encodable {
    let parameter: FloconDeeplink.Parameter

    init(_ parameter: FloconDeeplink.Parameter) {
        self.parameter = parameter
    }

    private enum CodingKeys: String, CodingKey {
        case type, name, autoComplete, suggestions, variableName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch parameter {
        case .autoComplete(let name, let suggestions):
            try container.encode("auto_complete", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(suggestions, forKey: .autoComplete)
        case .suggestions(let name, let suggestions):
            // the values stay in `autoComplete` for desktops that do not know `suggestions` yet
            try container.encode("auto_complete", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(suggestions.map(\.value), forKey: .autoComplete)
            try container.encode(suggestions.map(DeeplinkSuggestionRemote.init), forKey: .suggestions)
        case .variable(let name, let variableName):
            try container.encode("variable", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(variableName, forKey: .variableName)
        }
    }
}

/// JSON format of a deeplink variable. The `mode` is omitted for a free text input.
struct DeeplinkVariableRemote: Encodable {
    let name: String
    let mode: Mode?
    let description: String?

    /// JSON format of the suggestions of a variable, tagged by `type`.
    struct Mode: Encodable {
        let type = "auto_complete"
        /// The values only, for desktops that do not know `items` yet.
        let suggestions: [String]
        let items: [DeeplinkSuggestionRemote]?
    }

    init(_ variable: FloconDeeplinkVariable) {
        name = variable.name
        mode = variable.suggestions.map { values in
            Mode(suggestions: values, items: variable.suggestionItems.map { $0.map(DeeplinkSuggestionRemote.init) })
        }
        description = variable.description
    }
}

/// JSON format of a suggestion. The label and the default flag are omitted when they have no value.
struct DeeplinkSuggestionRemote: Encodable {
    let value: String
    let label: String?
    let isDefault: Bool

    init(_ suggestion: FloconDeeplinkSuggestion) {
        value = suggestion.value
        label = suggestion.label
        isDefault = suggestion.isDefault
    }

    private enum CodingKeys: String, CodingKey {
        case value, label, isDefault
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(label, forKey: .label)
        if isDefault {
            try container.encode(true, forKey: .isDefault)
        }
    }
}
#endif
