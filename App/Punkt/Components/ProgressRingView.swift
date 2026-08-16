import SwiftUI

/// A soft ring that fills over a reference period (default 60 min per lap)
/// rather than racing toward a hard target — the session has no finish
/// line to fail at.
struct ProgressRingView: View {
    var progress: Double // 0...1, wraps every lap
    var color: Color
    var lineWidth: CGFloat = 6
    var diameter: CGFloat = 220

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.002, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}

/// Elapsed-time progress within a soft reference period, e.g. 60 minutes
/// per lap of the ring — the fraction resets every `referencePeriod`.
func lapProgress(startedAt: Date, now: Date, referencePeriod: TimeInterval) -> Double {
    guard referencePeriod > 0 else { return 0 }
    let elapsed = max(0, now.timeIntervalSince(startedAt))
    return elapsed.truncatingRemainder(dividingBy: referencePeriod) / referencePeriod
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ProgressRingView(progress: 0.4, color: PunktPalette.active)
    }
}
