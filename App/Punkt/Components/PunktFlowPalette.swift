import SwiftUI

/// Colors ported 1:1 from the original Flow Tracker HTML prototype
/// (`--ramp-color`, `--flow-color`, `--exit-color`), kept separate from
/// `PunktPalette` since Flow mode is visually its own thing by design.
enum PunktFlowPalette {
    static let ramp = Color(red: 0xAF / 255, green: 0xA9 / 255, blue: 0xEC / 255)
    static let flow = Color(red: 0x5D / 255, green: 0xCA / 255, blue: 0xA5 / 255)
    static let exit = Color(red: 0xEF / 255, green: 0x9F / 255, blue: 0x27 / 255)
}
