import SwiftUI

/// The animated sine-wave flourish shown during the flow phase, ported
/// from the original prototype's `animateWave()` (a two-frequency sine
/// sum, redrawn continuously).
struct WaveView: View {
    var color: Color

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphicsContext, size in
                let t = context.date.timeIntervalSinceReferenceDate * 1.45
                var path = Path()
                let midY = size.height / 2
                let step: CGFloat = 3
                var x: CGFloat = 0
                var isFirstPoint = true

                while x <= size.width {
                    let y = midY
                        + sin(Double(x) / 50 + t) * 7
                        + sin(Double(x) / 25 + t * 1.4) * 3.5
                    let point = CGPoint(x: x, y: y)
                    if isFirstPoint {
                        path.move(to: point)
                        isFirstPoint = false
                    } else {
                        path.addLine(to: point)
                    }
                    x += step
                }

                graphicsContext.stroke(path, with: .color(color.opacity(0.8)), lineWidth: 1.5)
            }
        }
        .frame(height: 36)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        WaveView(color: PunktFlowPalette.flow)
            .frame(width: 240)
    }
}
