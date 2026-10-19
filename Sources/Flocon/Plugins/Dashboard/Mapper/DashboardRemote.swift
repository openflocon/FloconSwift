import Foundation

/// An action of the app, run when the desktop app sends the matching event.
enum DashboardCallback: Sendable {
    case button(@MainActor @Sendable () -> Void)
    case textField(@MainActor @Sendable (String) -> Void)
    case checkBox(@MainActor @Sendable (Bool) -> Void)
    /// The values sent by the desktop are keyed by action identifier, `<dashboardId>_<inputId>`.
    case form(dashboardId: String, @MainActor @Sendable ([String: String]) -> Void)
}

/// JSON format of a dashboard sent to the desktop app, same as the Android SDK.
///
/// The identifiers sent are action identifiers, `<dashboardId>_<elementId>`, unique across dashboards.
struct DashboardRemote: Encodable {
    let dashboardId: String
    let containers: [DashboardContainerRemote]

    /// Maps a dashboard, and lists the actions of its elements by action identifier.
    static func make(_ config: FloconDashboardConfig) -> (remote: DashboardRemote, callbacks: [String: DashboardCallback]) {
        var callbacks: [String: DashboardCallback] = [:]
        let containers = config.containers.map { container in
            DashboardContainerRemote(container, dashboardId: config.id, callbacks: &callbacks)
        }
        return (DashboardRemote(dashboardId: config.id, containers: containers), callbacks)
    }

    static func actionId(dashboardId: String, elementId: String) -> String {
        dashboardId + "_" + elementId
    }
}

/// JSON format of a section or a form.
struct DashboardContainerRemote: Encodable {
    let name: String
    let elements: [DashboardElementRemote]
    let containerConfig: DashboardContainerConfigRemote

    init(_ container: FloconDashboardContainer, dashboardId: String, callbacks: inout [String: DashboardCallback]) {
        name = container.name
        elements = container.elements.map { DashboardElementRemote($0, dashboardId: dashboardId, callbacks: &callbacks) }
        switch container.kind {
        case .section:
            containerConfig = DashboardContainerConfigRemote(containerType: "SECTION", formId: nil, submitText: nil)
        case .form(let submitText, let onSubmitted):
            let formId = DashboardRemote.actionId(dashboardId: dashboardId, elementId: "form_" + container.name)
            callbacks[formId] = .form(dashboardId: dashboardId, onSubmitted)
            containerConfig = DashboardContainerConfigRemote(containerType: "FORM", formId: formId, submitText: submitText)
        }
    }
}

/// JSON format of the kind of a container, tagged by `containerType`.
struct DashboardContainerConfigRemote: Encodable {
    let containerType: String
    let formId: String?
    let submitText: String?
}

/// JSON format of an element: an object with a single key naming its kind, such as `{"text": {...}}`.
struct DashboardElementRemote: Encodable {
    private let key: Key
    private let value: Value

    private enum Key: String, CodingKey {
        case text, label, button, textField, checkBox, plainText, markdown, html
    }

    private struct Value: Encodable {
        var id: String?
        var text: String?
        var label: String?
        var placeHolder: String?
        var value: ElementValue?
        /// Signed 32-bit ARGB, like `Color.toArgb()` on Android: the desktop reads a Kotlin `Int`.
        var color: Int32?
        var type: String?
    }

    private enum ElementValue: Encodable {
        case string(String)
        case bool(Bool)

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value): try container.encode(value)
            case .bool(let value): try container.encode(value)
            }
        }
    }

    init(_ element: FloconDashboardElement, dashboardId: String, callbacks: inout [String: DashboardCallback]) {
        switch element.kind {
        case .text(let label, let value, let color):
            key = .text
            self.value = Value(label: label, value: .string(value), color: color.map(Int32.init(truncatingIfNeeded:)))
        case .label(let label, let color):
            key = .label
            value = Value(label: label, color: color.map(Int32.init(truncatingIfNeeded:)))
        case .button(let text, let id, let onClick):
            let actionId = DashboardRemote.actionId(dashboardId: dashboardId, elementId: id)
            callbacks[actionId] = .button(onClick)
            key = .button
            value = Value(id: actionId, text: text)
        case .textField(let id, let label, let placeholder, let value, let onSubmitted):
            let actionId = DashboardRemote.actionId(dashboardId: dashboardId, elementId: id)
            callbacks[actionId] = .textField(onSubmitted)
            key = .textField
            self.value = Value(id: actionId, label: label, placeHolder: placeholder, value: .string(value))
        case .checkBox(let id, let label, let value, let onUpdated):
            let actionId = DashboardRemote.actionId(dashboardId: dashboardId, elementId: id)
            callbacks[actionId] = .checkBox(onUpdated)
            key = .checkBox
            self.value = Value(id: actionId, label: label, value: .bool(value))
        case .plainText(let label, let value, let type):
            key = .plainText
            self.value = Value(label: label, value: .string(value), type: type)
        case .markdown(let label, let value):
            key = .markdown
            self.value = Value(label: label, value: .string(value))
        case .html(let label, let value):
            key = .html
            self.value = Value(label: label, value: .string(value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(value, forKey: key)
    }
}

// MARK: - Messages from the desktop

/// Body of `onTextFieldSubmitted`.
struct DashboardTextFieldSubmittedRemote: Decodable {
    let id: String
    let value: String
}

/// Body of `onCheckBoxValueChanged`.
struct DashboardCheckBoxValueChangedRemote: Decodable {
    let id: String
    let value: Bool
}

/// Body of `onFormSubmitted`, with the values keyed by action identifier.
struct DashboardFormSubmittedRemote: Decodable {
    let id: String
    let values: [String: String]
}
