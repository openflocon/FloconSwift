import Foundation

/// A compiled regular expression that must match the whole text.
final class FloconRegex: @unchecked Sendable {
    // NSRegularExpression is immutable and safe to share between threads.
    private let expression: NSRegularExpression

    init?(fullMatch pattern: String) {
        guard let expression = try? NSRegularExpression(pattern: "^(?:\(pattern))$") else {
            FloconLogger.log("Invalid mock url pattern: \(pattern)")
            return nil
        }
        self.expression = expression
    }

    func matches(_ text: String) -> Bool {
        expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}
