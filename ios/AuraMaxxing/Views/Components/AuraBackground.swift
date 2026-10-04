import SwiftUI

/// Fond : aplat quasi noir + un grand disque plein de la couleur d'aura, coupé par le bord de l'écran.
/// Forme nette, statique, sans flou : un parti pris graphique plutôt qu'un halo « néon ».
struct AuraBackground: View {
    var colors: [Color] = [.auraPurple]
    var intensity: Double = 0.35

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                Color.auraBackground
                if intensity > 0, let color = colors.first {
                    Circle()
                        .fill(color.opacity(min(1, intensity * 0.6)))
                        .frame(width: geo.size.width * 1.1)
                        .offset(x: geo.size.width * 0.45, y: -geo.size.width * 0.35)
                    Circle()
                        .stroke(color.opacity(min(1, intensity * 1.2)), lineWidth: 2)
                        .frame(width: geo.size.width * 1.35)
                        .offset(x: geo.size.width * 0.55, y: -geo.size.width * 0.45)
                }
            }
        }
        .ignoresSafeArea()
    }
}
