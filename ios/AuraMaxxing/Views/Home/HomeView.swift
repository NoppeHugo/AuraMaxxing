import SwiftUI

/// Accueil : thème du jour, série, position dans la ligue, vidéos restantes, gros bouton d'analyse.
struct HomeView: View {

    @EnvironmentObject private var session: SessionStore
    var openLeague: () -> Void
    @State private var showUpload = false
    @State private var uploadChallenge: ChallengeInfo?
    @State private var challenges: MyChallenges?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let p = session.profile {
                    content(p)
                } else {
                    ProgressView().padding(.top, 120)
                }
            }
            .refreshable {
                await session.refresh()
                await loadChallenges()
            }
            .background(Color.auraBackground.ignoresSafeArea())
            .navigationTitle("AURA")
        }
        .fullScreenCover(isPresented: $showUpload, onDismiss: { Task { await loadChallenges() } }) {
            UploadFlowView(challenge: uploadChallenge)
        }
        .task { await loadChallenges() }
    }

    private func loadChallenges() async {
        challenges = try? await APIClient.shared.get("challenges")
    }

    private func startUpload(challenge: ChallengeInfo? = nil) {
        Haptics.thud()
        uploadChallenge = challenge
        showUpload = true
    }

    @ViewBuilder private func content(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            header(p)

            if let challenge = session.pendingChallenge, p.today.uploadsLeft > 0 {
                challengeBanner(challenge)
            }

            if let first = p.rivals.overtakenBy.first {
                Button(action: openLeague) {
                    rivalBanner(Self.overtakenTitle(first: first, count: p.rivals.overtakenBy.count),
                                p.rivals.ahead.map { "Il te manque \($0.gap) pts pour reprendre ta place." } ?? "Reprends ta place.",
                                color: .auraPink)
                }
                .buttonStyle(.plain)
            } else if let ahead = p.rivals.ahead {
                rivalBanner("\(ahead.gap) pts pour passer @\(ahead.pseudo)", "Une bonne vidéo et c'est fait.", color: .auraCyan)
            }

            themeCard(p.today)
            scoreboard(p)
            uploadCard(p.today)
            inviteCard(p.invite, full: p.today.uploadsLeft == 0)

            if let sent = challenges?.sent, !sent.isEmpty { myChallenges(sent) }
            if !p.recent.isEmpty { recentVideos(p.recent) }
        }
        .padding(16)
    }

    // MARK: - Sections

    private func header(_ p: Profile) -> some View {
        HStack(spacing: 12) {
            AvatarView(player: p.user, size: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text("@\(p.user.pseudo)").font(.heading(19))
                LeagueBadge(league: p.league)
            }
            Spacer()
        }
    }

    private func challengeBanner(_ challenge: ChallengeInfo) -> some View {
        Button {
            Analytics.track(.challengeAccepted)
            startUpload(challenge: challenge)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Défi reçu").eyebrow(Color.auraInk.opacity(0.7))
                    Text("@\(challenge.from?.pseudo ?? "?") · \(challenge.score)").font(.display(30)).foregroundStyle(Color.auraInk)
                    Text("Tu fais mieux ?").font(.subheadline.weight(.semibold)).foregroundStyle(Color.auraInk.opacity(0.8))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.title2.weight(.black))
                    .foregroundStyle(Color.auraInk)
            }
            .padding(16)
            .background(Color.auraGold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func rivalBanner(_ title: String, _ subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.heading(18))
            Text(subtitle).font(.subheadline).foregroundStyle(Color.auraMuted)
        }
        .padding(.leading, 6)
        .auraCard(padding: 14)
        .accentBar(color)
    }

    private func themeCard(_ today: Today) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Thème du jour").eyebrow(Color.auraGold)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    CountdownText(end: Date(timeIntervalSince1970: today.resetsAt / 1000))
                }
                .font(.caption.weight(.bold)).foregroundStyle(Color.auraMuted)
            }
            Text(today.theme.uppercased()).font(.display(38)).lineLimit(2).minimumScaleFactor(0.7)
            Text(today.hint).foregroundStyle(Color.auraMuted)
            HStack(spacing: 8) {
                StickerLabel(text: "+25 % de points", fill: .auraGold, angle: -2)
                Text(today.hashtag).font(.subheadline.weight(.heavy)).foregroundStyle(Color.auraGold)
            }
            .padding(.top, 4)
        }
        .auraCard(padding: 18)
    }

    /// Série + rang : deux grosses cases façon tableau de score.
    private func scoreboard(_ p: Profile) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Série").eyebrow()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(p.streak.days)").font(.display(52))
                    Image(systemName: "flame.fill").font(.title3).foregroundStyle(Color.auraPink)
                }
                Text(p.today.postedToday ? "Validé aujourd'hui" : "Prochaine : +\(Int(p.streak.bonus * 100)) %")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(p.today.postedToday ? Color.auraGreen : Color.auraPink)
            }
            .auraCard(padding: 14)

            Button(action: openLeague) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ligue · \(p.week.label)").eyebrow()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(p.week.rank.map { "#\($0)" } ?? "—").font(.display(52))
                        if let size = p.week.size, size > 0 {
                            Text("/\(size)").font(.display(22)).foregroundStyle(Color.auraMuted)
                        }
                    }
                    HStack(spacing: 4) {
                        Text("\(p.week.points ?? 0) pts ·")
                        CountdownText(end: p.week.endDate)
                    }
                    .font(.caption.weight(.bold)).foregroundStyle(Color.auraCyan)
                }
                .auraCard(padding: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private func uploadCard(_ today: Today) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Vidéos du jour").eyebrow()
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<today.uploadsMax, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < today.uploadsLeft ? Color.auraPurple : Color.white.opacity(0.12))
                            .frame(width: 22, height: 8)
                    }
                }
            }
            Button {
                startUpload()
            } label: {
                Label(today.uploadsLeft > 0 ? "Analyser une vidéo" : "Reviens demain", systemImage: "video.fill")
            }
            .buttonStyle(GlowButtonStyle())
            .disabled(today.uploadsLeft == 0)
            .opacity(today.uploadsLeft == 0 ? 0.5 : 1)
            Text("Seules tes 3 meilleures vidéos de la semaine comptent.")
                .font(.caption).foregroundStyle(Color.auraMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .auraCard()
    }

    /// Parrainage : chaque pote qui poste sa 1re vidéo = +1 vidéo par jour (le levier qui fait inviter).
    private func inviteCard(_ invite: Invite, full: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(full ? "Plus de vidéos aujourd'hui ?" : "Invite tes potes").eyebrow(Color.auraCyan)
            Text("+1 vidéo par jour pour chaque pote qui poste sa 1re vidéo")
                .font(.heading(19))
            HStack(spacing: 4) {
                ForEach(0..<invite.max, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < invite.bonus ? Color.auraCyan : Color.white.opacity(0.1))
                        .frame(height: 8)
                }
            }
            Text(Self.inviteStatus(invite)).font(.caption).foregroundStyle(Color.auraMuted)
            ShareLink(item: "Viens tester ton aura sur AuraMaxxing. Mon code : \(invite.code) → \(invite.url)") {
                Label("Inviter des potes", systemImage: "person.badge.plus")
            }
            .buttonStyle(GhostButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { Analytics.track(.inviteShared) })
        }
        .auraCard()
    }

    private func myChallenges(_ sent: [ChallengeInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mes défis").eyebrow().padding(.top, 8)
            ForEach(sent) { c in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(c.score)").font(.display(30))
                        Text("d'aura").font(.caption.weight(.bold)).foregroundStyle(Color.auraMuted)
                        Spacer()
                        Text(c.expired ? "Terminé" : c.code).eyebrow(c.expired ? .auraMuted : .auraGold)
                    }
                    if let results = c.results, !results.isEmpty {
                        ForEach(results.prefix(5), id: \.self) { r in
                            HStack {
                                Text("@\(r.pseudo)").font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(r.won ? "T'A BATTU" : "BATTU").eyebrow(r.won ? .auraRed : .auraGreen)
                                Text("\(r.score)").font(.display(20)).monospacedDigit().frame(width: 44, alignment: .trailing)
                            }
                        }
                    } else {
                        Text("Personne n'a encore répondu. Relance tes potes.").font(.caption).foregroundStyle(Color.auraMuted)
                    }
                }
                .auraCard(padding: 14)
            }
        }
    }

    private func recentVideos(_ videos: [VideoRecord]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tes dernières vidéos").eyebrow().padding(.top, 8).padding(.bottom, 8)
            ForEach(videos) { v in
                HStack(spacing: 12) {
                    Text("\(v.score)").font(.display(30)).monospacedDigit().frame(width: 62, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.title).font(.subheadline.weight(.bold)).lineLimit(1)
                        Text("\(v.tier) · +\(v.points) pts").font(.caption).foregroundStyle(Color.auraMuted)
                    }
                    Spacer()
                    if v.themeMatch { StickerLabel(text: "Thème", fill: .auraGold, angle: 0) }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.auraBorder).frame(height: 1) }
            }
        }
    }

    // MARK: - Textes

    static func overtakenTitle(first: String, count: Int) -> String {
        switch count {
        case 1: return "@\(first) t'a dépassé"
        case 2: return "@\(first) et 1 autre t'ont dépassé"
        default: return "@\(first) et \(count - 1) autres t'ont dépassé"
        }
    }

    static func inviteStatus(_ invite: Invite) -> String {
        var text = "\(invite.bonus)/\(invite.max) débloqué" + (invite.bonus > 1 ? "s" : "")
        let waiting = invite.invited - invite.active
        if waiting > 0 { text += " · \(waiting) en attente de leur 1re vidéo" }
        return text
    }
}
