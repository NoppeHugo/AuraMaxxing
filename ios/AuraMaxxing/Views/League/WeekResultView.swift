import SwiftUI

/// Écran plein de fin de saison : montée, maintien ou descente. Affiché une fois, le lundi.
struct WeekResultView: View {
    let result: WeekResult
    @Environment(\.dismiss) private var dismiss
    @State private var shown = false

    private var color: Color { Color(hex: result.leagueInfo.color) }

    private var headline: String {
        switch result.outcome {
        case .up: return "PROMU·E !"
        case .stay: return "Saison terminée"
        case .down: return "Relégation…"
        }
    }

    private var message: String {
        switch result.outcome {
        case .up: return "Bienvenue en \(result.leagueInfo.name). Les adversaires sont plus forts, l'aura aussi."
        case .stay: return "Tu restes en \(result.leagueInfo.name). Cette semaine, vise le top pour monter."
        case .down: return "Tu redescends en \(result.leagueInfo.name). Nouvelle semaine, revanche immédiate."
        }
    }

    var body: some View {
        ZStack {
            AuraBackground(colors: [color, .auraPurple, color], intensity: 0.35)
            ParticleField(colors: [color, .white], count: 50, speed: 0.8).ignoresSafeArea()
            if result.outcome == .up || result.rank == 1 { ConfettiView(colors: [color, .auraGold, .white]) }

            VStack(spacing: 18) {
                Spacer()
                Text(result.leagueInfo.emoji)
                    .font(.system(size: 120))
                    .shadow(color: color, radius: 40)
                    .scaleEffect(shown ? 1 : 0.2)
                    .rotationEffect(.degrees(shown ? 0 : -30))
                Text(headline).font(.system(size: 40, weight: .black, design: .rounded))
                Text(message).font(.title3).multilineTextAlignment(.center).foregroundStyle(Color.auraMuted)
                HStack(spacing: 30) {
                    stat("\(result.rank)/\(result.size)", "classement")
                    stat("\(result.points)", "points")
                }
                .padding(.top, 10)
                Spacer()
                Button("C'est reparti") {
                    Analytics.track(.weekResultSeen, ["outcome": result.outcome.rawValue])
                    dismiss()
                }
                .buttonStyle(GlowButtonStyle(colors: [color, .auraPurple]))
            }
            .padding(24)
        }
        .onAppear {
            if result.outcome == .down { Haptics.error() } else { Haptics.success() }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.5)) { shown = true }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.system(size: 30, weight: .black, design: .rounded))
            Text(label).font(.caption).foregroundStyle(Color.auraMuted)
        }
    }
}
