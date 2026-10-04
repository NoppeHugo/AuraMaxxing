import SwiftUI

/// Écran d'attente : les images clés défilent sous un laser de scan.
struct AnalyzingView: View {
    let frames: [UIImage]

    @State private var index = 0
    @State private var message = 0
    @State private var scan = false

    private let messages = [
        "Calibrage du détecteur d'aura…",
        "Analyse de ta présence à l'écran…",
        "Mesure de l'énergie main character…",
        "Détection du drip…",
        "Comparaison avec les trends du moment…",
        "Vérification du thème du jour…",
        "Calcul des points d'aura…",
    ]

    var body: some View {
        ZStack {
            Color.auraBackground.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    if !frames.isEmpty {
                        Image(uiImage: frames[index % frames.count])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 240, height: 320)
                            .saturation(0.6)
                            .brightness(-0.1)
                            .id(index)
                            .transition(.opacity)
                    }
                    // Grille + laser
                    GridPattern().stroke(Color.auraCyan.opacity(0.18), lineWidth: 1)
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.auraCyan)
                            .frame(height: 3)
                            .offset(y: scan ? geo.size.height - 3 : 0)
                    }
                }
                .frame(width: 240, height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.auraCyan.opacity(0.5), lineWidth: 2))

                Text(messages[message % messages.count])
                    .font(.headline)
                    .id(message)
                    .transition(.push(from: .bottom))
                ProgressView().tint(.auraCyan)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { scan = true }
        }
        .task {
            // Fait défiler les images et les messages tant que l'analyse tourne.
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(450))
                tick += 1
                withAnimation(.easeInOut(duration: 0.3)) { index += 1 }
                if tick % 4 == 0 { withAnimation { message += 1 } }
            }
        }
    }
}

private struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 24
        stride(from: 0, through: rect.width, by: step).forEach { x in
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        stride(from: 0, through: rect.height, by: step).forEach { y in
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}
