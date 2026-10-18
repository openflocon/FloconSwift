import Foundation

// Identique à FloconMessageFromServer côté Kotlin (model/FloconMessageFromServer.kt).
public struct FloconMessageFromServer: Decodable {
    public let plugin: String
    public let method: String
    public let body: String
}
