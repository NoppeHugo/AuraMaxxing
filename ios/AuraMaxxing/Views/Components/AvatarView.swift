import SwiftUI
import UIKit

/// Miniature (si la personne l'a acceptée) ou initiales sur un dégradé aux couleurs de son aura.
struct AvatarView: View {
    let player: Player
    var size: CGFloat = 44

    var body: some View {
        let c1 = Color(hex: player.auraColor), c2 = Color(hex: player.auraColor2)
        ZStack {
            // Deux aplats coupés en diagonale (pas de dégradé).
            LinearGradient(stops: [.init(color: c1, location: 0.5), .init(color: c2, location: 0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let cover = player.cover, let image = Self.decode(cover) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(player.pseudo.prefix(2).uppercased())
                    .font(.system(size: size * 0.42, weight: .black).width(.compressed))
                    .foregroundStyle(Color.auraBackground)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.auraBackground, lineWidth: 2))
    }

    private static let cache = NSCache<NSString, UIImage>()

    static func decode(_ dataURL: String) -> UIImage? {
        if let hit = cache.object(forKey: dataURL as NSString) { return hit }
        guard let comma = dataURL.firstIndex(of: ","),
              let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...])),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: dataURL as NSString)
        return image
    }
}

/// Étiquette de ligue : aplat de la couleur de la ligue, nom en capitales condensées.
struct LeagueBadge: View {
    let league: LeagueInfo
    var compact = false

    var body: some View {
        Text(compact ? String(league.name.split(separator: " ").last ?? "") : league.name)
            .font(.system(size: 12, weight: .black).width(.condensed))
            .textCase(.uppercase)
            .kerning(1)
            .foregroundStyle(Color.readable(onHex: league.color))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color(hex: league.color), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// Stats en blocs (10 segments), façon jauge de jeu vidéo.
struct StatBarsView: View {
    let stats: Stats
    var colors: [Color] = [.auraPurple]
    @State private var shown = false

    var body: some View {
        VStack(spacing: 11) {
            ForEach(Array(stats.rows.enumerated()), id: \.offset) { i, row in
                HStack(spacing: 10) {
                    Text(row.label).eyebrow().frame(width: 88, alignment: .leading)
                    HStack(spacing: 3) {
                        ForEach(0..<10, id: \.self) { block in
                            let filled = shown && Double(block) < (Double(row.value) / 10).rounded(.up)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(filled ? (colors.first ?? .auraPurple) : Color.white.opacity(0.08))
                                .frame(height: 12)
                                .animation(.easeOut(duration: 0.15).delay(0.25 + Double(i) * 0.12 + Double(block) * 0.04), value: shown)
                        }
                    }
                    Text("\(row.value)").font(.display(20)).monospacedDigit().frame(width: 32, alignment: .trailing)
                }
            }
        }
        .onAppear { shown = true }
    }
}
