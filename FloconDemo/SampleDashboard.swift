import Combine
import Foundation
import Flocon

/// Sample dashboards, shown in the Dashboard section of Flocon Desktop.
///
/// Same dashboards as the Android sample: values of the app updated live, and actions run from the desktop.
final class SampleDashboard {
    struct User {
        var userName = "florent"
        var fullName = "Florent Champigny"
        var id = UUID().uuidString
    }

    struct Tokens {
        var accessToken = UUID().uuidString
        var refreshToken = UUID().uuidString
        var expiration = Date().addingTimeInterval(3600).formatted()
    }

    static let shared = SampleDashboard()

    @Published private var user = User()
    @Published private var tokens = Tokens()
    @Published private var isDarkTheme = false

    // keeps the dashboards up to date with the @Published properties
    private var handle: FloconDashboardHandle?

    private init() {}

    func start() {
        handle = floconDashboard(id: "main") {
            FloconSection("User", publisher: $user) { user in
                FloconText("username", user.userName)
                FloconText("fullName", user.fullName, color: 0xFFFF0000)
                FloconText("user id", user.id)
                FloconLabel("actions :")
                FloconButton("Change user name", id: "changeUserName") { [weak self] in
                    self?.user.userName = "__flo__"
                }
                FloconTextField(id: "changeFullName", label: "Update name", placeholder: "name", value: user.fullName) { [weak self] value in
                    self?.user.fullName = value
                }
            }
            FloconSection("Device", publisher: $isDarkTheme) { isDarkTheme in
                FloconText("name", ProcessInfo.processInfo.hostName)
                FloconText("systemVersion", ProcessInfo.processInfo.operatingSystemVersionString)
                FloconText("language", Locale.current.identifier)
                FloconCheckBox(id: "darkTheme", label: "darkTheme", value: isDarkTheme) { [weak self] value in
                    self?.isDarkTheme = value
                }
            }
            FloconSection("Tokens", publisher: $tokens) { tokens in
                FloconText("accessToken", tokens.accessToken)
                FloconText("refreshToken", tokens.refreshToken)
                FloconText("expiration", tokens.expiration)
                FloconButton("Clear access token", id: "clearAccessToken") { [weak self] in
                    self?.tokens.accessToken = ""
                }
            }
        }

        // static dashboards: no need to keep their handle
        floconDashboard(id: "plainText") {
            FloconSection("Test") {
                FloconPlainText(
                    "lorem",
                    "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam eget ullamcorper elit. Pellentesque turpis ex, cursus cursus urna sed, iaculis sagittis nisl."
                )
                FloconJSON(
                    "json",
                    """
                    {
                      "testData": {
                        "name": "John Doe",
                        "age": 30,
                        "isStudent": false,
                        "courses": [
                          { "title": "History I", "credits": 3 },
                          { "title": "Math II", "credits": 4 }
                        ]
                      },
                      "status": "success"
                    }
                    """
                )
            }
        }

        floconDashboard(id: "form") {
            FloconForm("Test form", submitText: "Submit form test button", onSubmitted: { values in
                // ["input_1": "test", "checkbox_1": "true"]
                print("[FloconDemo] form submitted: \(values)")
            }) {
                FloconTextField(id: "input_1", label: "Input field 1", placeholder: "placeholder", value: "test")
                FloconCheckBox(id: "checkbox_1", label: "Checkbox 1", value: true)
            }
        }

        floconDashboard(id: "markdown") {
            FloconSection("Markdown") {
                FloconMarkdown(
                    "Release Note",
                    """
                    # Release Note

                    This is a **markdown** text.

                    * [x] item 1
                    * [ ] item 2

                    Hello `world` !
                    """
                )
            }
        }

        floconDashboard(id: "html") {
            FloconSection("HTML Section") {
                FloconHTML("HtmlTitle", "<h1>Title</h1><p>Paragraph with <b>bold</b> text.</p>")
            }
        }
    }
}
