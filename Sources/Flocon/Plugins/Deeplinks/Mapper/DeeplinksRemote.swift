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
        case type, name, autoComplete, variableName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch parameter {
        case .autoComplete(let name, let suggestions):
            try container.encode("auto_complete", forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(suggestions, forKey: .autoComplete)
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
        let suggestions: [String]
    }

    init(_ variable: FloconDeeplinkVariable) {
        name = variable.name
        mode = variable.suggestions.map { Mode(suggestions: $0) }
        description = variable.description
    }
}
