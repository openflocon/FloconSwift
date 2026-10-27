import Combine
import Foundation

/// A group of inputs sent together to the app, with a submit button.
///
/// The values are keyed by the identifiers of the ``FloconTextField`` and ``FloconCheckBox``
/// of the form. Check boxes are sent as `"true"` or `"false"`:
///
/// ```swift
/// FloconForm("Create user", submitText: "Create", onSubmitted: { values in
///     createUser(name: values["name"] ?? "", isAdmin: values["admin"] == "true")
/// }) {
///     FloconTextField(id: "name", label: "Name", value: "")
///     FloconCheckBox(id: "admin", label: "Admin", value: false)
/// }
/// ```
public struct FloconForm {
    let content: FloconDashboardContent

    /// Creates a static form.
    ///
    /// - Parameters:
    ///   - name: Title of the form, unique in its dashboard.
    ///   - submitText: Text of the submit button. Defaults to `"Submit"`.
    ///   - onSubmitted: Called on the main actor with the values of the form, keyed by input identifier.
    ///   - content: The inputs of the form.
    public init(
        _ name: String,
        submitText: String = "Submit",
        onSubmitted: @escaping @MainActor @Sendable ([String: String]) -> Void,
        @FloconDashboardElementsBuilder content: () -> [FloconDashboardElement]
    ) {
        let container = FloconDashboardContainer(
            name: name,
            elements: content(),
            kind: .form(submitText: submitText, onSubmitted: onSubmitted)
        )
        self.content = FloconDashboardContent(publisher: Just(container).eraseToAnyPublisher())
    }

    /// Creates a form rebuilt each time the publisher emits.
    ///
    /// - Parameters:
    ///   - name: Title of the form, unique in its dashboard.
    ///   - submitText: Text of the submit button. Defaults to `"Submit"`.
    ///   - publisher: The data shown by the form, such as a `@Published` property or a `CurrentValueSubject`.
    ///   - onSubmitted: Called on the main actor with the values of the form, keyed by input identifier.
    ///   - content: Builds the inputs of the form from the latest value. Called on the thread the publisher emits on.
    public init<P: Publisher>(
        _ name: String,
        submitText: String = "Submit",
        publisher: P,
        onSubmitted: @escaping @MainActor @Sendable ([String: String]) -> Void,
        @FloconDashboardElementsBuilder content: @escaping (P.Output) -> [FloconDashboardElement]
    ) where P.Failure == Never {
        self.content = FloconDashboardContent(
            publisher: publisher
                .map {
                    FloconDashboardContainer(
                        name: name,
                        elements: content($0),
                        kind: .form(submitText: submitText, onSubmitted: onSubmitted)
                    )
                }
                .eraseToAnyPublisher()
        )
    }
}
