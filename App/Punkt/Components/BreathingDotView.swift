import SwiftUI

/// The central metaphor: a single circle that breathes slowly (~5s cycle).
/// Never a spinner, never urgent — `reduceMotion` freezes it at rest scale
/// entirely rather than reducing amplitude, per Apple's accessibility intent.
struct BreathingDotView: View {
    var color: Color
    var diameter: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .scaleEffect(reduceMotion ? 1.0 : (isExpanded ? 1.06 : 0.94))
            .shadow(color: color.opacity(0.5), radius: isExpanded ? 24 : 12)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                    isExpanded = true
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        BreathingDotView(color: PunktPalette.active)
    }
}
