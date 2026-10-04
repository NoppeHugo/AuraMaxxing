import SwiftUI

/// Accueil : thème du jour, série, position dans la ligue, vidéos restantes, gros bouton d'analyse.
struct HomeView: View {

    @EnvironmentObject private var session: SessionStore
    var openLeague: () -> Void
    @State private var showUpload = false

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
                .refreshable { await session.refresh() }
            }
            .navigationTitle("AuraMaxxing")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showUpload) {
            UploadFlowView()
        }
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
                Text("+25 % de points si ta vidéo colle au thème")
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
                    Haptics.thud()
                    showUpload = true
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
}
