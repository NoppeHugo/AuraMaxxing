import SwiftUI

/// Classements : ma ligue (groupe de 30, zones de montée/descente), top monde de la semaine, légendes.
/// Mise en page « tableau de championnat » : rangs en gros chiffres, lignes séparées par des filets.
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        modePicker
                        switch mode {
                        case .league: leagueSection
                        case .world: worldSection(world?.topVideos ?? [])
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
            .background(Color.auraBackground.ignoresSafeArea())
            .navigationTitle("CLASSEMENT")
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

    /// Onglets en texte souligné (plutôt qu'un segmented control générique).
    private var modePicker: some View {
        HStack(spacing: 22) {
            ForEach(Mode.allCases, id: \.self) { m in
                Button {
                    Haptics.tap()
                    mode = m
                } label: {
                    VStack(spacing: 6) {
                        Text(m.rawValue.uppercased())
                            .font(.system(size: 16, weight: .black).width(.condensed))
                            .foregroundStyle(mode == m ? .white : Color.auraMuted)
                        Rectangle().fill(mode == m ? Color.auraPurple : .clear).frame(height: 3)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Ma ligue

    @ViewBuilder private var leagueSection: some View {
        if let board {
            header(board)
            if !board.joined {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pas encore classé·e").eyebrow(Color.auraGold)
                    Text("Poste ta 1re vidéo de la semaine").font(.heading(22))
                    Text("Tu rejoins un groupe de 30 joueurs de la \(board.league.name). Le top \(board.zones.promote) monte lundi.")
                        .foregroundStyle(Color.auraMuted)
                }
                .auraCard(padding: 18)
            } else {
                motivation(board)
                VStack(spacing: 0) {
                    ForEach(Array(board.entries.enumerated()), id: \.element.rowID) { i, player in
                        if i == board.zones.promote && board.zones.promote > 0 {
                            zoneDivider("Promotion", systemImage: "arrow.up", .auraGreen)
                        }
                        if board.zones.demote > 0 && i == board.entries.count - board.zones.demote {
                            zoneDivider("Relégation", systemImage: "arrow.down", .auraRed)
                        }
                        row(player, value: player.points ?? 0, unit: "pts")
                            .id(player.rowID)
                    }
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
        }
    }

    private func header(_ board: LeagueBoard) -> some View {
        let current = board.league.index ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(board.league.name.uppercased()).font(.display(34)).foregroundStyle(Color(hex: board.league.color))
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("Fin de saison").eyebrow()
                    CountdownText(end: board.week.endDate).font(.display(22))
                }
            }
            // Échelle des 5 ligues : niveaux pleins jusqu'à la mienne.
            HStack(spacing: 4) {
                ForEach(Array(board.leagues.enumerated()), id: \.offset) { i, league in
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i <= current ? Color(hex: league.color) : Color.white.opacity(0.1))
                            .frame(height: i == current ? 10 : 6)
                        Text(String(league.name.split(separator: " ").last ?? "").uppercased())
                            .font(.system(size: 9, weight: .heavy).width(.condensed))
                            .foregroundStyle(i == current ? .white : Color.auraMuted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .auraCard()
    }

    /// Ce qui donne envie de reposter : combien il manque pour la zone de promotion / le joueur juste devant.
    @ViewBuilder private func motivation(_ board: LeagueBoard) -> some View {
        if let me = board.entries.first(where: { $0.isMe == true }), let rank = me.rank {
            let myPoints = me.points ?? 0
            let text: String? = {
                if rank == 1 { return "T'es #1 du groupe. Tiens jusqu'à dimanche minuit." }
                if rank > board.zones.promote, board.zones.promote > 0,
                   let last = board.entries.first(where: { $0.rank == board.zones.promote }) {
                    return "Il te manque \((last.points ?? 0) - myPoints + 1) pts pour la zone de promotion."
                }
                if let ahead = board.entries.first(where: { $0.rank == rank - 1 }) {
                    return "\((ahead.points ?? 0) - myPoints + 1) pts pour passer devant @\(ahead.pseudo)."
                }
                return nil
            }()
            if let text {
                Text(text)
                    .font(.heading(17))
                    .foregroundStyle(Color.auraInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.auraCyan, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Monde & légendes

    private func worldSection(_ players: [Player]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Meilleure vidéo de chaque joueur cette semaine").eyebrow().padding(.bottom, 8)
            if players.isEmpty { emptyState("Personne n'a encore posté cette semaine.") }
            ForEach(Array(players.enumerated()), id: \.element.rowID) { i, p in
                row(withRank(p, i + 1), value: p.score ?? 0, unit: "aura", subtitle: p.title)
            }
        }
    }

    private var legendsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Vainqueurs de la Ligue Mythique").eyebrow().padding(.bottom, 8)
            let legends = world?.legends ?? []
            if legends.isEmpty { emptyState("Aucune légende pour l'instant. Ce sera peut-être toi.") }
            ForEach(legends, id: \.rowID) { p in
                row(p, value: p.points ?? 0, unit: "pts", subtitle: "Champion·ne \(p.label ?? "")")
            }
        }
    }

    // MARK: - Lignes

    private func row(_ p: Player, value: Int, unit: String, subtitle: String? = nil) -> some View {
        let me = p.isMe == true
        let rankColor: Color = p.rank == 1 ? .auraGold : (me ? .white : .auraMuted)
        return HStack(spacing: 12) {
            Text(p.rank.map { "\($0)" } ?? "")
                .font(.display(26)).monospacedDigit()
                .foregroundStyle(rankColor)
                .frame(width: 34, alignment: .leading)
            AvatarView(player: p, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(p.pseudo).font(.subheadline.weight(.heavy)).lineLimit(1)
                    if p.streak > 1 {
                        HStack(spacing: 1) {
                            Image(systemName: "flame.fill")
                            Text("\(p.streak)")
                        }
                        .font(.caption2.weight(.heavy)).foregroundStyle(Color.auraPink)
                    }
                }
                Text(subtitle ?? p.tier).font(.caption).foregroundStyle(Color.auraMuted).lineLimit(1)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)").font(.display(24)).monospacedDigit()
                Text(unit).font(.caption2.weight(.bold)).foregroundStyle(Color.auraMuted)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, me ? 10 : 0)
        .background(me ? Color.auraPurple.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .leading) { if me { Rectangle().fill(Color.auraPurple).frame(width: 4) } }
        .overlay(alignment: .bottom) { if !me { Rectangle().fill(Color.auraBorder).frame(height: 1) } }
        .contentShape(Rectangle())
        .onLongPressGesture { if !me { Haptics.tap(); reportTarget = p } }
    }

    private func withRank(_ p: Player, _ rank: Int) -> Player {
        var copy = p
        copy.rank = rank
        return copy
    }

    private func zoneDivider(_ text: String, systemImage: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.caption.weight(.black))
            Text(text).eyebrow(color)
            Rectangle().fill(color).frame(height: 2)
        }
        .foregroundStyle(color)
        .padding(.vertical, 8)
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
