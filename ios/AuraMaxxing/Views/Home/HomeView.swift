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
            ZStack {
                AuraBackground(intensity: 0.22)
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
            }
            .navigationTitle("AuraMaxxing")
            .toolbarBackground(.hidden, for: .navigationBar)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                AvatarView(player: p.user, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Salut \(p.user.pseudo)").font(.title3.weight(.heavy))
                    LeagueBadge(league: p.league)
                }
                Spacer()
            }

            // Défi reçu par lien
            if let challenge = session.pendingChallenge, p.today.uploadsLeft > 0 {
                Button {
                    Analytics.track(.challengeAccepted)
                    startUpload(challenge: challenge)
                } label: {
                    HStack(spacing: 12) {
                        Text("⚔️").font(.system(size: 34))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(challenge.from?.pseudo ?? "?") t'a défié").font(.headline)
                            Text("Son score : \(challenge.score). Tu fais mieux ?").font(.subheadline).foregroundStyle(Color.auraMuted)
                        }
                        Spacer()
                        Text("Relever").font(.subheadline.weight(.heavy))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(LinearGradient.auraBrand, in: Capsule())
                    }
                    .auraCard()
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(hex: challenge.auraColor), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }

            // Rivalité : quelqu'un m'a dépassé, ou combien il manque pour passer devant.
            if let first = p.rivals.overtakenBy.first {
                Button(action: openLeague) {
                    rivalBanner(
                        Self.overtakenTitle(first: first, count: p.rivals.overtakenBy.count),
                        p.rivals.ahead.map { "Il te manque \($0.gap) pts pour reprendre ta place." } ?? "Reprends ta place."
                    )
                }
                .buttonStyle(.plain)
            } else if let ahead = p.rivals.ahead {
                rivalBanner("🎯 Plus que \(ahead.gap) pts pour passer @\(ahead.pseudo)", "Une bonne vidéo et c'est fait.")
            }

            // Thème du jour
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("⚡ THÈME DU JOUR").font(.caption.weight(.heavy)).foregroundStyle(Color.auraGold)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        CountdownText(end: Date(timeIntervalSince1970: p.today.resetsAt / 1000))
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(Color.auraMuted)
                }
                Text(p.today.theme).font(.system(size: 26, weight: .black, design: .rounded))
                Text(p.today.hint).foregroundStyle(Color.auraMuted)
                Text("+25 % de points si ta vidéo colle au thème · \(p.today.hashtag)")
                    .font(.caption.weight(.bold)).foregroundStyle(Color.auraGold)
            }
            .auraCard(padding: 18)
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.auraGold.opacity(0.35)))

            HStack(spacing: 12) {
                // Série
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔥 \(p.streak.days)").font(.system(size: 30, weight: .black, design: .rounded))
                    Text(p.streak.days > 1 ? "jours d'affilée" : "jour de série").font(.caption).foregroundStyle(Color.auraMuted)
                    Text(p.today.postedToday ? "Validé aujourd'hui ✓" : "Prochaine vidéo : +\(Int(p.streak.bonus * 100)) %")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(p.today.postedToday ? Color.auraGreen : Color.auraPink)
                }
                .auraCard()

                // Ligue de la semaine
                Button(action: openLeague) {
                    VStack(alignment: .leading, spacing: 4) {
                        if let rank = p.week.rank {
                            Text("#\(rank)").font(.system(size: 30, weight: .black, design: .rounded))
                            Text("sur \(p.week.size ?? 0) · \(p.week.points ?? 0) pts").font(.caption).foregroundStyle(Color.auraMuted)
                        } else {
                            Text("—").font(.system(size: 30, weight: .black, design: .rounded))
                            Text("pas encore classé·e").font(.caption).foregroundStyle(Color.auraMuted)
                        }
                        HStack(spacing: 4) {
                            Text("Fin \(p.week.label) :")
                            CountdownText(end: p.week.endDate)
                        }
                        .font(.caption.weight(.bold)).foregroundStyle(Color.auraCyan)
                    }
                    .auraCard()
                }
                .buttonStyle(.plain)
            }

            // Vidéos restantes + CTA
            VStack(spacing: 12) {
                HStack {
                    Text("Vidéos du jour").font(.subheadline.weight(.semibold))
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<p.today.uploadsMax, id: \.self) { i in
                            Circle()
                                .fill(i < p.today.uploadsLeft ? AnyShapeStyle(LinearGradient.auraBrand) : AnyShapeStyle(Color.white.opacity(0.15)))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                Button {
                    startUpload()
                } label: {
                    Label(p.today.uploadsLeft > 0 ? "Analyser une vidéo" : "Reviens demain", systemImage: "sparkles")
                }
                .buttonStyle(GlowButtonStyle())
                .disabled(p.today.uploadsLeft == 0)
                .opacity(p.today.uploadsLeft == 0 ? 0.5 : 1)
                Text("Seules tes 3 meilleures vidéos de la semaine comptent : vise la qualité.")
                    .font(.caption).foregroundStyle(Color.auraMuted)
            }
            .auraCard()

            inviteCard(p.invite, full: p.today.uploadsLeft == 0)

            if let sent = challenges?.sent, !sent.isEmpty {
                Text("Mes défis").font(.headline).padding(.top, 8)
                ForEach(sent) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("⚔️ \(c.score) d'aura").font(.subheadline.weight(.heavy))
                            Spacer()
                            Text(c.expired ? "terminé" : "code \(c.code)").font(.caption.weight(.bold)).foregroundStyle(Color.auraMuted)
                        }
                        if let results = c.results, !results.isEmpty {
                            ForEach(results.prefix(5), id: \.self) { r in
                                HStack {
                                    Text(r.won ? "😤" : "😎")
                                    Text("@\(r.pseudo)").font(.subheadline)
                                    Spacer()
                                    Text("\(r.score)").font(.subheadline.weight(.bold)).monospacedDigit()
                                        .foregroundStyle(r.won ? Color.auraRed : Color.auraGreen)
                                }
                            }
                        } else {
                            Text("Personne n'a encore répondu. Relance tes potes !").font(.caption).foregroundStyle(Color.auraMuted)
                        }
                    }
                    .auraCard(padding: 12)
                }
            }

            if !p.recent.isEmpty {
                Text("Tes dernières vidéos").font(.headline).padding(.top, 8)
                ForEach(p.recent) { v in
                    HStack(spacing: 12) {
                        Text(v.emoji).font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.title).font(.subheadline.weight(.bold)).lineLimit(1)
                            Text("\(v.tier) · +\(v.points) pts\(v.themeMatch ? " · ⚡" : "")")
                                .font(.caption).foregroundStyle(Color.auraMuted)
                        }
                        Spacer()
                        Text("\(v.score)").font(.title3.weight(.black)).monospacedDigit()
                    }
                    .auraCard(padding: 12)
                }
            }
        }
        .padding(16)
    }

    static func overtakenTitle(first: String, count: Int) -> String {
        switch count {
        case 1: return "😤 @\(first) t'a dépassé"
        case 2: return "😤 @\(first) et 1 autre t'ont dépassé"
        default: return "😤 @\(first) et \(count - 1) autres t'ont dépassé"
        }
    }

    static func inviteStatus(_ invite: Invite) -> String {
        var text = "\(invite.bonus)/\(invite.max) débloqué" + (invite.bonus > 1 ? "s" : "")
        let waiting = invite.invited - invite.active
        if waiting > 0 { text += " · \(waiting) en attente de leur 1re vidéo" }
        return text
    }

    private func rivalBanner(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(Color.auraMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LinearGradient(colors: [Color.auraPink.opacity(0.35), Color.auraPurple.opacity(0.2)],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 18))
    }

    /// Parrainage : chaque pote qui poste sa 1re vidéo = +1 vidéo par jour (le levier qui fait inviter).
    private func inviteCard(_ invite: Invite, full: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(full ? "Plus de vidéos aujourd'hui ? Invite un pote 👇" : "Invite tes potes, gagne des vidéos")
                .font(.headline)
            Text("Chaque pote qui poste sa 1re vidéo = +1 vidéo par jour pour toi (jusqu'à +\(invite.max)).")
                .font(.subheadline).foregroundStyle(Color.auraMuted)
            HStack(spacing: 6) {
                ForEach(0..<invite.max, id: \.self) { i in
                    Capsule()
                        .fill(i < invite.bonus ? AnyShapeStyle(LinearGradient.auraBrand) : AnyShapeStyle(Color.white.opacity(0.12)))
                        .frame(height: 8)
                }
            }
            Text(Self.inviteStatus(invite))
                .font(.caption).foregroundStyle(Color.auraMuted)
            ShareLink(item: "Viens tester ton aura sur AuraMaxxing 🗿 Mon code : \(invite.code) → \(invite.url)") {
                Label("Inviter des potes", systemImage: "person.badge.plus")
            }
            .buttonStyle(GhostButtonStyle())
            .simultaneousGesture(TapGesture().onEnded { Analytics.track(.inviteShared) })
        }
        .auraCard()
    }
}
