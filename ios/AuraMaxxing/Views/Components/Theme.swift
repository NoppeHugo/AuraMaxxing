import SwiftUI

extension Color {
    /// Fond principal — #07060D
    static let auraBackground = Color(hex: "#07060D")
    /// Cartes — blanc 5 %
    static let auraCard = Color.white.opacity(0.05)
    static let auraBorder = Color.white.opacity(0.09)
    /// Violet signature — #B46BFF
    static let auraPurple = Color(hex: "#B46BFF")
    /// Rose néon — #FF3D81
    static let auraPink = Color(hex: "#FF3D81")
    /// Cyan — #3DE8FF
    static let auraCyan = Color(hex: "#3DE8FF")
    static let auraGold = Color(hex: "#FFD25E")
    static let auraGreen = Color(hex: "#4ADE80")
    static let auraRed = Color(hex: "#F87171")
    static let auraMuted = Color(hex: "#A39FBD")

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
}

extension LinearGradient {
    static let auraBrand = LinearGradient(colors: [.auraPurple, .auraPink], startPoint: .leading, endPoint: .trailing)
}

/// Carte sombre translucide utilisée partout.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.auraCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.auraBorder))
    }
}

extension View {
    func auraCard(padding: CGFloat = 16) -> some View { modifier(CardModifier(padding: padding)) }
}

/// Gros bouton dégradé avec halo.
struct GlowButtonStyle: ButtonStyle {
    var colors: [Color] = [.auraPurple, .auraPink]
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing), in: Capsule())
            .shadow(color: (colors.first ?? .auraPurple).opacity(0.55), radius: 18, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.auraCard, in: Capsule())
            .overlay(Capsule().stroke(Color.auraBorder))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
