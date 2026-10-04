import SwiftUI
import UIKit

// Direction artistique : affiche de sport / streetwear plutôt que « néon IA ».
// Aplats de couleur, typo condensée en capitales, chiffres massifs, angles nets, peu d'effets.
// La palette reste la même : violet, rose, cyan, or sur fond quasi noir.

extension Color {
    /// Fond principal — #07060D
    static let auraBackground = Color(hex: "#07060D")
    /// Surface des cartes (aplat, pas de verre dépoli) — #13111C
    static let auraCard = Color(hex: "#13111C")
    /// Surface surélevée — #1C1928
    static let auraRaised = Color(hex: "#1C1928")
    static let auraBorder = Color(hex: "#262236")
    /// Violet signature — #B46BFF
    static let auraPurple = Color(hex: "#B46BFF")
    /// Rose — #FF3D81
    static let auraPink = Color(hex: "#FF3D81")
    /// Cyan — #3DE8FF
    static let auraCyan = Color(hex: "#3DE8FF")
    static let auraGold = Color(hex: "#FFD25E")
    static let auraGreen = Color(hex: "#4ADE80")
    static let auraRed = Color(hex: "#F87171")
    static let auraMuted = Color(hex: "#9C98B4")
    /// Encre foncée posée sur les aplats clairs.
    static let auraInk = Color(hex: "#0B0A12")

    /// "#RRGGBB" → Color (gris si invalide).
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        guard clean.count == 6, Scanner(string: clean).scanHexInt64(&value) else {
            self = .gray
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Texte lisible (encre ou blanc) posé sur une couleur d'aura quelconque.
    static func readable(onHex hex: String) -> Color {
        let ui = UIColor(hex: hex)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        return luminance > 0.18 ? .auraInk : .white
    }
}

// MARK: - Typographie

extension Font {
    /// Titres et chiffres : système, très gras, compressé (look affiche / tableau de score).
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed)
    }

    /// Sous-titres forts, légèrement condensés.
    static func heading(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .heavy).width(.condensed)
    }
}

extension Text {
    /// Petit libellé en capitales espacées, au-dessus d'un bloc.
    func eyebrow(_ color: Color = .auraMuted) -> some View {
        self.font(.system(size: 12, weight: .heavy).width(.condensed))
            .kerning(1.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

/// Barre de navigation : grands titres en typo compressée.
enum NavigationStyle {
    static func apply() {
        let large = UIFont.systemFont(ofSize: 40, weight: .black, width: .compressed)
        let inline = UIFont.systemFont(ofSize: 18, weight: .heavy, width: .condensed)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(Color.auraBackground)
        appearance.largeTitleTextAttributes = [.font: large, .foregroundColor: UIColor.white]
        appearance.titleTextAttributes = [.font: inline, .foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Cartes

/// Carte en aplat, angles modérés, filet discret.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    var fill: Color = .auraCard
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.auraBorder, lineWidth: 1))
    }
}

extension View {
    func auraCard(padding: CGFloat = 16, fill: Color = .auraCard) -> some View {
        modifier(CardModifier(padding: padding, fill: fill))
    }

    /// Bloc accentué : barre de couleur pleine sur la gauche (au lieu d'un halo).
    func accentBar(_ color: Color) -> some View {
        overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14, style: .continuous)
                .fill(color)
                .frame(width: 5)
        }
    }
}

// MARK: - Boutons

/// Bouton principal : aplat de couleur, texte foncé en capitales condensées. Pas de dégradé ni de halo.
struct GlowButtonStyle: ButtonStyle {
    var colors: [Color] = [.auraPurple]
    var textColor: Color = .auraInk

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .black).width(.condensed))
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(colors.first ?? .auraPurple, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .offset(y: configuration.isPressed ? 2 : 0)
            .background( // ombre portée « dure », façon sticker
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .offset(y: 4)
            )
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Bouton secondaire : contour blanc.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .heavy).width(.condensed))
            .textCase(.uppercase)
            .kerning(0.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(configuration.isPressed ? Color.auraRaised : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.85), lineWidth: 1.5))
    }
}

/// Étiquette façon autocollant, légèrement penchée.
struct StickerLabel: View {
    let text: String
    var fill: Color = .auraGold
    var angle: Double = -3

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .black).width(.condensed))
            .textCase(.uppercase)
            .kerning(0.8)
            .foregroundStyle(Color.readable(onHex: fill.hexString))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(fill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .rotationEffect(.degrees(angle))
    }
}

extension Color {
    /// "#RRGGBB" depuis une Color (pour réutiliser `readable(onHex:)`).
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
