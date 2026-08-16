import SwiftUI

/// The app's only color states (§6). Deliberately no red — "Nein" and
/// unanswered check-ins are never framed as failure.
enum PunktPalette {
    static let background = Color.black
    static let active = Color(red: 0.32, green: 0.62, blue: 0.58) // ruhiges Grün/Teal
    static let checkIn = Color(red: 0.55, green: 0.85, blue: 0.78) // kurzes Aufhellen
    static let detour = Color(red: 0.82, green: 0.62, blue: 0.28) // Amber
    static let returnDue = Color(red: 0.92, green: 0.70, blue: 0.30) // pulsierendes Amber
    static let idle = Color(white: 0.4)
    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)
}
