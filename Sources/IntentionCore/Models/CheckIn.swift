import Foundation
import SwiftData

/// A single "Bist du noch dabei?" moment and how it was resolved.
///
/// `actualActivityText` is an optional, always-skippable note about what
/// the person was actually doing when they answered "no" — never required.
@Model
public final class CheckIn {
    public var id: UUID
    public var at: Date
    public var responseRawValue: String
    public var actualActivityText: String?
    public var session: Session?

    public init(
        at: Date = .now,
        response: CheckInResponse = .unanswered,
        actualActivityText: String? = nil
    ) {
        self.id = UUID()
        self.at = at
        self.responseRawValue = response.rawValue
        self.actualActivityText = actualActivityText
    }

    public var response: CheckInResponse {
        get { CheckInResponse(rawValue: responseRawValue) ?? .unanswered }
        set { responseRawValue = newValue.rawValue }
    }
}
