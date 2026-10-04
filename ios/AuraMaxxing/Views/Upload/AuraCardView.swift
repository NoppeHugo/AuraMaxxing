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
            Circle().fill(c1).frame(width: 460).offset(x: 170, y: -250)
            Circle().stroke(c2, lineWidth: 3).frame(width: 560).offset(x: 190, y: -260)

            VStack(spacing: 14) {
                Text("AURAMAXXING").font(.display(26)).frame(maxWidth: .infinity, alignment: .leading)
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: 210, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(c1, lineWidth: 4))
                        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(c2).offset(x: 9, y: 9))
                }
                Text("@\(pseudo)").font(.headline).foregroundStyle(Color.auraMuted)
                Text("\(analysis.auraScore)")
                    .font(.display(120))
                    .foregroundStyle(.white)
                Text("\(analysis.emoji) \(analysis.tier.uppercased())").font(.system(size: 18, weight: .black)).kerning(1.5)
                Text(analysis.title).font(.system(size: 15, weight: .semibold)).italic()
                    .foregroundStyle(Color.auraMuted).multilineTextAlignment(.center)
                Text(analysis.trends.map { "#" + $0.name.filter { $0.isLetter || $0.isNumber } }.joined(separator: "  "))
                    .font(.caption.weight(.bold)).foregroundStyle(Color.auraMuted)
                Text("T'AS COMBIEN D'AURA ?").font(.display(22)).padding(.top, 6)
            }
            .padding(24)
        }
        .frame(width: 360, height: 640)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}
