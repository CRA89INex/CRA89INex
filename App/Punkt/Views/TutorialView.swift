import SwiftUI

/// A short, swipeable explainer for the core idea and the three modes.
/// Shown once on first launch (see `RootView`) and reachable again anytime
/// from Einstellungen. Deliberately just four calm cards — no confetti,
/// no "3 of 12 tips", nothing that turns understanding the app into a
/// task of its own.
struct TutorialView: View {
    var onFinished: () -> Void

    @State private var page = 0

    private let pages: [TutorialPage] = [
        TutorialPage(
            color: PunktPalette.active,
            title: "Die Idee",
            body: "Du erklärst, was du jetzt tun willst. Die Zeit läuft sichtbar. In unregelmäßigen Abständen fragt Punkt kurz: „Bist du noch dabei?" Kein Blockieren, keine Bewertung — nur freundliches Bewusstmachen."
        ),
        TutorialPage(
            color: PunktPalette.active,
            title: "Vertiefung",
            body: "Seltene Check-ins, etwa alle 20–40 Minuten. Für Tätigkeiten, die ungestörten Fokus brauchen — der Flow hat Vorrang vor der Nachfrage."
        ),
        TutorialPage(
            color: PunktPalette.checkIn,
            title: "Wachheit",
            body: "Häufigere Check-ins, etwa alle 6–12 Minuten. Für Tätigkeiten, bei denen du erfahrungsgemäß leicht abschweifst und ein kurzer Anstoß hilft."
        ),
        TutorialPage(
            color: PunktFlowPalette.ramp,
            title: "Flow",
            body: "Kein Check-in-Modus. Erst ein kurzer Anlauf zum Ankommen, dann offene Flow-Zeit, die du selbst beendest, wenn du fertig bist."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Überspringen") { onFinished() }
                    .font(.footnote)
                    .foregroundStyle(PunktPalette.textSecondary)
                    .padding()
            }

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, tutorialPage in
                    TutorialPageView(page: tutorialPage)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? PunktPalette.textPrimary : PunktPalette.textSecondary.opacity(0.3))
                        .frame(width: index == page ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: page)
                }
            }
            .padding(.bottom, 24)

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinished()
                }
            } label: {
                Text(page < pages.count - 1 ? "Weiter" : "Los geht's")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(pages[page].color)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(PunktPalette.background.ignoresSafeArea())
    }
}

private struct TutorialPage {
    let color: Color
    let title: String
    let body: String
}

private struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Circle()
                .fill(page.color)
                .frame(width: 56, height: 56)
                .shadow(color: page.color.opacity(0.5), radius: 16)

            Text(page.title)
                .font(.title2.weight(.medium))
                .foregroundStyle(PunktPalette.textPrimary)

            Text(page.body)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(PunktPalette.textSecondary)
                .frame(maxWidth: 300)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    TutorialView(onFinished: {})
}
