import SwiftUI
import WidgetKit

/// Widget : rang dans la ligue, points, série et compte à rebours de fin de saison.
/// Visible plusieurs fois par jour sur l'écran d'accueil → rappel permanent de jouer.

struct AuraEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct AuraProvider: TimelineProvider {
    func placeholder(in context: Context) -> AuraEntry { AuraEntry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (AuraEntry) -> Void) {
        completion(AuraEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AuraEntry>) -> Void) {
        // L'app recharge le widget à chaque rafraîchissement ; sinon mise à jour toutes les heures.
        let entry = AuraEntry(date: .now, snapshot: WidgetSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct AuraWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        if let s = entry.snapshot {
            switch family {
            case .accessoryRectangular: lockScreen(s)
            case .accessoryCircular: circular(s)
            default: home(s)
            }
        } else {
            VStack(spacing: 6) {
                Text("🗿").font(.largeTitle)
                Text("Ouvre AuraMaxxing").font(.caption.weight(.bold))
            }
        }
    }

    private func home(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(s.leagueEmoji)
                Text(s.leagueName).font(.caption2.weight(.heavy)).foregroundStyle(Color(widgetHex: s.leagueColor))
            }
            Spacer(minLength: 0)
            Text(s.rank.map { "#\($0)" } ?? "—").font(.system(size: 38, weight: .black, design: .rounded))
            Text(s.rank == nil ? "poste ta vidéo" : "sur \(s.size) · \(s.points) pts")
                .font(.caption2).foregroundStyle(.secondary)
            if let ahead = s.aheadPseudo, let gap = s.aheadGap {
                Text("\(gap) pts pour passer @\(ahead)").font(.caption2.weight(.bold)).lineLimit(1)
            }
            HStack(spacing: 4) {
                Text("🔥\(s.streak)")
                Spacer()
                Text(s.weekEndsAt, style: .relative).monospacedDigit()
            }
            .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
    }

    private func lockScreen(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(s.leagueEmoji) \(s.rank.map { "#\($0)/\(s.size)" } ?? "Pas classé·e") · 🔥\(s.streak)")
                .font(.headline)
            Text("\(s.points) pts · fin dans ") + Text(s.weekEndsAt, style: .relative)
        }
    }

    private func circular(_ s: WidgetSnapshot) -> some View {
        VStack(spacing: 0) {
            Text(s.leagueEmoji)
            Text(s.rank.map { "#\($0)" } ?? "—").font(.system(size: 16, weight: .black))
        }
    }
}

@main
struct AuraWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraWidget", provider: AuraProvider()) { entry in
            AuraWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(widgetHex: "#1A1030"), Color(widgetHex: "#07060D")],
                                   startPoint: .top, endPoint: .bottom)
                }
                .widgetURL(URL(string: "auramaxxing://league"))
        }
        .configurationDisplayName("Ma ligue d'aura")
        .description("Ton rang, ta série et la fin de la saison.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}

private extension Color {
    init(widgetHex hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
