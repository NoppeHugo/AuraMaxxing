import SwiftUI

/// Carte d'aura au format story (rendue en image 1080×1920 pour le partage).
struct AuraCardView: View {
    let analysis: VideoAura
    let pseudo: String
    let photo: UIImage?

    var body: some View {
        let c1 = Color(hex: analysis.auraColor), c2 = Color(hex: analysis.auraColor2)
        ZStack {
            Color.auraBackground
            Circle().fill(c1.opacity(0.55)).frame(width: 420).blur(radius: 90).offset(x: -120, y: -180)
            Circle().fill(c2.opacity(0.45)).frame(width: 420).blur(radius: 90).offset(x: 140, y: 120)

            VStack(spacing: 14) {
                Text("AuraMaxxing").font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.auraPurple, .auraCyan], startPoint: .leading, endPoint: .trailing))
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: 210, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(c1, lineWidth: 3))
                        .shadow(color: c1, radius: 30)
                }
                Text("@\(pseudo)").font(.headline).foregroundStyle(Color.auraMuted)
                Text("\(analysis.auraScore)")
                    .font(.system(size: 92, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [c1, .white, c2], startPoint: .leading, endPoint: .trailing))
                Text("\(analysis.emoji) \(analysis.tier.uppercased())").font(.system(size: 18, weight: .black)).kerning(1.5)
                Text(analysis.title).font(.system(size: 15, weight: .semibold)).italic()
                    .foregroundStyle(Color.auraMuted).multilineTextAlignment(.center)
                Text(analysis.trends.map { "#" + $0.name.filter { $0.isLetter || $0.isNumber } }.joined(separator: "  "))
                    .font(.caption.weight(.bold)).foregroundStyle(Color.auraMuted)
                Text("T'as combien d'aura ? 👀").font(.footnote.weight(.heavy)).padding(.top, 6)
            }
            .padding(24)
        }
        .frame(width: 360, height: 640)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}
