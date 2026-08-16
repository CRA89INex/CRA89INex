import Foundation

/// How a check-in was resolved.
public enum CheckInResponse: String, Codable, Sendable {
    case yes
    case no
    case unanswered
}
