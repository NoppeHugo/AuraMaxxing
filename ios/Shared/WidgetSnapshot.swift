import Foundation

/// Données partagées entre l'app et le widget (App Group).
/// L'app les écrit à chaque rafraîchissement du profil ; le widget les lit.
struct WidgetSnapshot: Codable {
    var pseudo: String
    var leagueEmoji: String
    var leagueName: String
    var leagueColor: String
    var rank: Int?
    var size: Int
    var points: Int
    var streak: Int
    var weekEndsAt: Date
    var theme: String
    var aheadPseudo: String?
    var aheadGap: Int?

    static let appGroup = "group.com.hugonoppe.auramaxxing"
    private static let key = "widget-snapshot"

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }

    static let placeholder = WidgetSnapshot(
        pseudo: "toi", leagueEmoji: "💡", leagueName: "Ligue Néon", leagueColor: "#3DE8FF",
        rank: 4, size: 30, points: 1840, streak: 3, weekEndsAt: Date().addingTimeInterval(2 * 86_400),
        theme: "Walk-in de main character", aheadPseudo: "leo", aheadGap: 120
    )
}
