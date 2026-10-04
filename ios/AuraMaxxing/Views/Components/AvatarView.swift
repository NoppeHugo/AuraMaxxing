import SwiftUI
import UIKit

/// Miniature (si la personne l'a acceptée) ou initiales sur un dégradé aux couleurs de son aura.
struct AvatarView: View {
    let player: Player
    var size: CGFloat = 44

    var body: some View {
        let c1 = Color(hex: player.auraColor), c2 = Color(hex: player.auraColor2)
        ZStack {
            LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let cover = player.cover, let image = Self.decode(cover) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(player.pseudo.prefix(2).uppercased())
                    .font(.system(size: size * 0.38, weight: .black, design: .rounded))
                    .foregroundStyle(Color.auraBackground)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: c1.opacity(0.6), radius: size / 5)
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

/// Pastille de ligue (emoji + nom) aux couleurs de la ligue.
struct LeagueBadge: View {
    let league: LeagueInfo
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Text(league.emoji)
            if !compact { Text(league.name).font(.system(size: 13, weight: .heavy)) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(Color(hex: league.color))
        .background(Color(hex: league.color).opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(Color(hex: league.color).opacity(0.4)))
    }
}

/// Barres de stats animées.
struct StatBarsView: View {
    let stats: Stats
    var colors: [Color] = [.auraPurple, .auraPink]
    @State private var shown = false

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(stats.rows.enumerated()), id: \.offset) { i, row in
                HStack(spacing: 10) {
                    Text(row.label).font(.subheadline).foregroundStyle(Color.auraMuted).frame(width: 92, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07))
                            Capsule()
                                .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                                .frame(width: shown ? geo.size.width * CGFloat(row.value) / 100 : 0)
                                .animation(.spring(duration: 1.1).delay(0.15 * Double(i)), value: shown)
                        }
                    }
                    .frame(height: 10)
                    Text("\(row.value)").font(.subheadline.weight(.heavy)).monospacedDigit().frame(width: 32, alignment: .trailing)
                }
            }
        }
        .onAppear { shown = true }
    }
}
