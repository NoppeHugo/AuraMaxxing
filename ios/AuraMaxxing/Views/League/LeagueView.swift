import SwiftUI

/// Classements : ma ligue (groupe de 30, zones de montée/descente), top monde de la semaine, légendes.
struct LeagueView: View {

    @EnvironmentObject private var session: SessionStore
    @State private var mode: Mode = .league
    @State private var board: LeagueBoard?
    @State private var world: WorldBoard?
    @State private var error: String?
    @State private var reportTarget: Player?

    enum Mode: String, CaseIterable { case league = "Ma ligue", world = "Monde", legends = "Légendes" }

    var body: some View {
        NavigationStack {
            ZStack {
                AuraBackground(intensity: 0.18)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 14) {
                            Picker("", selection: $mode) {
                                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                            }
                            .pickerStyle(.segmented)

                            switch mode {
                            case .league: leagueSection
                            case .world: worldSection(world?.topVideos ?? [], scoreLabel: "aura")
                            case .legends: legendsSection
                            }
                            if let error { Text(error).foregroundStyle(Color.auraRed) }
                        }
                        .padding(16)
                    }
                    .refreshable { await load() }
                    .onChange(of: board?.entries.count) { _, _ in
                        if let me = board?.entries.first(where: { $0.isMe == true }) {
                            withAnimation { proxy.scrollTo(me.rowID, anchor: .center) }
                        }
                    }
                }
            }
            .navigationTitle("Classement")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            Analytics.track(.leagueViewed)
            await load()
        }
        .confirmationDialog("Que veux-tu faire ?", isPresented: Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }), presenting: reportTarget) { target in
            Button("Signaler \(target.pseudo)", role: .destructive) { Task { await moderate("report", target) } }
            Button("Bloquer \(target.pseudo)", role: .destructive) { Task { await moderate("block", target) } }
        }
    }

    // MARK: - Ma ligue

    @ViewBuilder private var leagueSection: some View {
        if let board {
            header(board)
            if !board.joined {
                VStack(spacing: 10) {
                    Text("🎬").font(.system(size: 44))
                    Text("Poste ta 1re vidéo de la semaine").font(.headline)
                    Text("Tu rejoindras un groupe de \(30) joueurs de la \(board.league.name). Le top \(board.zones.promote) monte de ligue lundi.")
                        .multilineTextAlignment(.center).foregroundStyle(Color.auraMuted)
                }
                .auraCard(padding: 22)
            } else {
                motivation(board)
                VStack(spacing: 6) {
                    ForEach(Array(board.entries.enumerated()), id: \.element.rowID) { i, player in
                        if i == board.zones.promote && board.zones.promote > 0 {
                            zoneDivider("⬆️ ZONE DE PROMOTION", .auraGreen)
                        }
                        if board.zones.demote > 0 && i == board.entries.count - board.zones.demote {
                            zoneDivider("⬇️ ZONE DE RELÉGATION", .auraRed)
                        }
                        row(player, value: player.points ?? 0, unit: "pts")
                            .id(player.rowID)
                    }
                }
            }
        } else {
            ProgressView().padding(.top, 60)
        }
    }

    private func header(_ board: LeagueBoard) -> some View {
        VStack(spacing: 12) {
            // Échelle des ligues : où je suis, où je peux aller.
            HStack(spacing: 6) {
                ForEach(Array(board.leagues.enumerated()), id: \.offset) { i, league in
                    let current = i == board.league.index
                    VStack(spacing: 4) {
                        Text(league.emoji).font(.system(size: current ? 34 : 22))
                            .opacity(i <= (board.league.index ?? 0) ? 1 : 0.35)
                            .shadow(color: current ? Color(hex: league.color) : .clear, radius: 12)
                        Capsule().fill(current ? Color(hex: league.color) : Color.white.opacity(0.12)).frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack {
                LeagueBadge(league: board.league)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                    Text("Fin de saison")
                    CountdownText(end: board.week.endDate)
                }
                .font(.caption.weight(.bold)).foregroundStyle(Color.auraCyan)
            }
        }
        .auraCard()
    }

    /// Le message qui donne envie de reposter : combien il manque pour la zone de promotion / le joueur juste devant.
    @ViewBuilder private func motivation(_ board: LeagueBoard) -> some View {
        if let me = board.entries.first(where: { $0.isMe == true }), let rank = me.rank {
            let myPoints = me.points ?? 0
            let text: String? = {
                if rank == 1 { return "👑 T'es #1 du groupe. Tiens bon jusqu'à dimanche minuit !" }
                if rank > board.zones.promote, board.zones.promote > 0,
                   let last = board.entries.first(where: { $0.rank == board.zones.promote }) {
                    return "Il te manque \((last.points ?? 0) - myPoints + 1) pts pour entrer dans la zone de promotion ⬆️"
                }
                if let ahead = board.entries.first(where: { $0.rank == rank - 1 }) {
                    return "Plus que \((ahead.points ?? 0) - myPoints + 1) pts pour passer devant \(ahead.pseudo) 🔥"
                }
                return nil
            }()
            if let text {
                Text(text)
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(LinearGradient(colors: [Color.auraPurple.opacity(0.35), Color.auraPink.opacity(0.25)],
                                               startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Monde & légendes

    private func worldSection(_ players: [Player], scoreLabel: String) -> some View {
        VStack(spacing: 6) {
            Text("Meilleure vidéo de chaque joueur cette semaine, toutes ligues confondues.")
                .font(.caption).foregroundStyle(Color.auraMuted)
            if players.isEmpty { emptyState("Personne n'a encore posté cette semaine.") }
            ForEach(Array(players.enumerated()), id: \.element.rowID) { i, p in
                var ranked = p
                let _ = (ranked.rank = i + 1)
                row(ranked, value: p.score ?? 0, unit: scoreLabel, subtitle: "\(p.emoji) \(p.title)")
            }
        }
    }

    private var legendsSection: some View {
        VStack(spacing: 6) {
            Text("Les vainqueurs de la Ligue Mythique, semaine après semaine.")
                .font(.caption).foregroundStyle(Color.auraMuted)
            let legends = world?.legends ?? []
            if legends.isEmpty { emptyState("Aucune légende pour l'instant. Ce sera peut-être toi 👑") }
            ForEach(legends, id: \.rowID) { p in
                row(p, value: p.points ?? 0, unit: "pts", subtitle: "👑 \(p.label ?? "")")
            }
        }
    }

    // MARK: - Lignes

    private func row(_ p: Player, value: Int, unit: String, subtitle: String? = nil) -> some View {
        let me = p.isMe == true
        return HStack(spacing: 12) {
            Text(p.rank.map { $0 <= 3 ? ["🥇", "🥈", "🥉"][$0 - 1] : "\($0)" } ?? "")
                .font(.system(size: 16, weight: .black)).frame(width: 30)
                .foregroundStyle(Color.auraMuted)
            AvatarView(player: p, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(p.pseudo).font(.subheadline.weight(.heavy)).lineLimit(1)
                    if p.streak > 1 { Text("🔥\(p.streak)").font(.caption2.weight(.bold)) }
                }
                Text(subtitle ?? "\(p.emoji) \(p.tier)").font(.caption).foregroundStyle(Color.auraMuted).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(value)").font(.headline.weight(.black)).monospacedDigit()
                Text(unit).font(.caption2).foregroundStyle(Color.auraMuted)
            }
        }
        .padding(10)
        .background(me ? AnyShapeStyle(LinearGradient(colors: [Color.auraPurple.opacity(0.4), Color.auraPink.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                       : AnyShapeStyle(Color.auraCard),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(me ? Color.auraPurple : Color.clear, lineWidth: 1.5))
        .contentShape(Rectangle())
        .onLongPressGesture { if !me { Haptics.tap(); reportTarget = p } }
    }

    private func zoneDivider(_ text: String, _ color: Color) -> some View {
        HStack {
            Rectangle().fill(color.opacity(0.5)).frame(height: 1)
            Text(text).font(.caption2.weight(.heavy)).foregroundStyle(color).fixedSize()
            Rectangle().fill(color.opacity(0.5)).frame(height: 1)
        }
        .padding(.vertical, 6)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text).foregroundStyle(Color.auraMuted).frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    // MARK: - Données

    private func load() async {
        do {
            async let b: LeagueBoard = APIClient.shared.get("league")
            async let w: WorldBoard = APIClient.shared.get("global")
            (board, world) = try await (b, w)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func moderate(_ action: String, _ target: Player) async {
        let _: OkResponse? = try? await APIClient.shared.post(action, UserIdBody(userId: target.id))
        if action == "report" { Analytics.track(.userReported) }
        await load()
    }
}
