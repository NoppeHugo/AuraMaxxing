import SwiftUI

/// Révélation du score : halo + particules aux couleurs de l'aura, compteur, tier, points de ligue.
struct ResultView: View {
    let result: UploadResult
    let frames: [UIImage]
    let sourceURL: URL
    let pseudo: String
    let leagueLine: String
    let hashtag: String
    let onDone: () -> Void

    @State private var stage = 0
    @State private var pulse = false
    @State private var shareImage: Image?
    // Vidéo de révélation
    @State private var revealURL: URL?
    @State private var exporting = false
    // Défi
    @State private var challenge: ChallengeInfo?
    @State private var creatingChallenge = false
    @State private var actionError: String?

    private var a: VideoAura { result.analysis }
    private var c1: Color { Color(hex: a.auraColor) }
    private var c2: Color { Color(hex: a.auraColor2) }
    private var peak: UIImage? { frames.indices.contains(a.peakFrame) ? frames[a.peakFrame] : frames.first }

    var body: some View {
        ZStack {
            AuraBackground(colors: [c1, c2, c1], intensity: 0.3)
            ParticleField(colors: [c1, c2, .white], count: 40 + a.auraScore / 15, speed: 0.6 + Double(a.auraScore) / 1000)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    if stage >= 2, let outcome = result.challenge {
                        challengeCard(outcome).transition(.scale.combined(with: .opacity))
                    }
                    if stage >= 2 { pointsCard.transition(.move(edge: .bottom).combined(with: .opacity)) }
                    if stage >= 3 { details.transition(.opacity) }
                    if stage >= 3 { actions }
                }
                .padding(20)
                .padding(.top, 20)
            }

            if stage >= 1 && (result.isRecord || a.auraScore >= 750 || result.challenge?.won == true) {
                ConfettiView(colors: [c1, c2, .auraGold, .white])
            }
        }
        .task { await reveal() }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 10) {
            if let peak {
                Image(uiImage: peak)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 266)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(LinearGradient(colors: [c1, c2], startPoint: .top, endPoint: .bottom), lineWidth: 3))
                    .shadow(color: pulse ? c2 : c1, radius: pulse ? 50 : 28)
                    .scaleEffect(pulse ? 1.02 : 1)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
                    }
            }
            Text("Pic d'aura : \(a.peakMoment)")
                .font(.caption).foregroundStyle(Color.auraMuted)
                .multilineTextAlignment(.center)

            CountingText(value: a.auraScore)
                .foregroundStyle(LinearGradient(colors: [c1, .white, c2], startPoint: .leading, endPoint: .trailing))
                .shadow(color: c1.opacity(0.6), radius: 20)
            Text("points d'aura").font(.subheadline).foregroundStyle(Color.auraMuted).offset(y: -10)

            if stage >= 1 {
                Text("\(a.emoji) \(a.tier.uppercased())")
                    .font(.system(size: 15, weight: .black))
                    .kerning(1.5)
                    .foregroundStyle(Color.auraBackground)
                    .padding(.horizontal, 18).padding(.vertical, 9)
                    .background(LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                Text(a.title).font(.title2.weight(.heavy)).multilineTextAlignment(.center)
                if result.isRecord {
                    Text("🚀 Nouveau record perso !").font(.headline).foregroundStyle(Color.auraGold)
                }
            }
        }
    }

    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !a.contentOk {
                Label("Vidéo non conforme aux règles : 0 point.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.auraRed)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("+\(result.video.points)").font(.system(size: 40, weight: .black, design: .rounded))
                    Text("pts de ligue").foregroundStyle(Color.auraMuted)
                    Spacer()
                    rankChange
                }
                HStack(spacing: 8) {
                    if result.video.themeMatch { chip("⚡ Thème du jour +25 %", .auraGold) }
                    if result.video.streakBonus > 0 { chip("🔥 Série +\(Int(result.video.streakBonus * 100)) %", .auraPink) }
                }
                Text(result.counted
                     ? "Cette vidéo compte dans ton top 3 de la semaine (\(result.weekPoints) pts au total)."
                     : "Pas dans ton top 3 de la semaine : seules tes 3 meilleures vidéos comptent.")
                    .font(.footnote).foregroundStyle(Color.auraMuted)
            }
        }
        .auraCard()
    }

    @ViewBuilder private var rankChange: some View {
        let before = result.rankBefore ?? result.lobbySize
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                if result.rankAfter < before {
                    Image(systemName: "arrow.up").foregroundStyle(Color.auraGreen)
                }
                Text("#\(result.rankAfter)").font(.title3.weight(.black))
            }
            Text("sur \(result.lobbySize)").font(.caption).foregroundStyle(Color.auraMuted)
        }
    }

    private var details: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stats").font(.headline)
                StatBarsView(stats: a.stats, colors: [c1, c2])
            }
            .auraCard()

            VStack(alignment: .leading, spacing: 12) {
                Text("Trends détectées").font(.headline)
                FlowChips(items: a.trends.map { "\($0.name) · \($0.confidence) %" })
                quote("🔥 HYPE", a.hype)
                quote("💀 ROAST", a.roast)
            }
            .auraCard()

            VStack(alignment: .leading, spacing: 8) {
                Text("Pour gagner +aura").font(.headline)
                ForEach(a.tips, id: \.self) { Label($0, systemImage: "arrow.up.right.circle.fill") }
            }
            .auraCard()
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            // 1. La vidéo de révélation : le format qui se poste sur TikTok / Reels.
            if let revealURL {
                ShareLink(item: revealURL, preview: SharePreview("Mon aura : \(a.auraScore)")) {
                    Label("Poster ma vidéo d'aura", systemImage: "paperplane.fill")
                }
                .buttonStyle(GlowButtonStyle(colors: [c1, c2]))
                .simultaneousGesture(TapGesture().onEnded { Analytics.track(.revealShared) })
            } else {
                Button {
                    Task { await exportReveal() }
                } label: {
                    if exporting {
                        HStack(spacing: 10) { ProgressView().tint(.white); Text("Montage en cours…") }
                    } else {
                        Label("Créer ma vidéo d'aura", systemImage: "film.stack")
                    }
                }
                .buttonStyle(GlowButtonStyle(colors: [c1, c2]))
                .disabled(exporting)
            }

            // 2. Défier un pote : le lien l'amène à installer l'app pour répondre.
            if a.contentOk {
                if let challenge, let text = challenge.shareText {
                    ShareLink(item: text) {
                        Label("Envoyer le défi (code \(challenge.code))", systemImage: "bolt.fill")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded { Analytics.track(.challengeShared) })
                } else {
                    Button {
                        Task { await createChallenge() }
                    } label: {
                        if creatingChallenge { ProgressView().tint(.white) } else { Label("Défier un pote", systemImage: "bolt.fill") }
                    }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(creatingChallenge)
                }
            }
            if let actionError { Text(actionError).font(.footnote).foregroundStyle(Color.auraRed) }

            if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview("Mon aura : \(a.auraScore)", image: shareImage)) {
                    Label("Partager ma carte d'aura", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(GhostButtonStyle())
                .simultaneousGesture(TapGesture().onEnded { Analytics.track(.resultShared) })
            }
            Button("Terminer", action: onDone).buttonStyle(GhostButtonStyle())
        }
        .padding(.top, 6)
    }

    private func challengeCard(_ outcome: ChallengeOutcome) -> some View {
        VStack(spacing: 6) {
            Text(outcome.won ? "⚔️ DÉFI GAGNÉ" : "⚔️ DÉFI PERDU")
                .font(.caption.weight(.heavy)).kerning(1.5)
                .foregroundStyle(outcome.won ? Color.auraGold : Color.auraMuted)
            Text(outcome.won ? "T'as battu @\(outcome.opponent) !" : "@\(outcome.opponent) garde la couronne… pour l'instant")
                .font(.title3.weight(.heavy)).multilineTextAlignment(.center)
            Text("\(outcome.myScore) vs \(outcome.opponentScore)")
                .font(.system(size: 30, weight: .black, design: .rounded)).monospacedDigit()
            Text(outcome.won ? "Envoie-lui ta vidéo d'aura 😏" : "Tu peux retenter avec une autre vidéo pendant 72 h.")
                .font(.footnote).foregroundStyle(Color.auraMuted)
        }
        .frame(maxWidth: .infinity)
        .auraCard()
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(outcome.won ? Color.auraGold : Color.auraBorder, lineWidth: 1.5))
    }

    private func exportReveal() async {
        exporting = true
        actionError = nil
        defer { exporting = false }
        let challengeLine = result.challenge.map {
            $0.won ? "⚔️ J'ai battu @\($0.opponent) : \($0.myScore) vs \($0.opponentScore)"
                   : "⚔️ Défi contre @\($0.opponent) : \($0.myScore) vs \($0.opponentScore)"
        }
        do {
            revealURL = try await RevealVideoExporter.export(
                source: sourceURL,
                content: .init(analysis: a, pseudo: pseudo, leagueLine: leagueLine, hashtag: hashtag, challengeLine: challengeLine)
            )
            Haptics.success()
            Analytics.track(.revealExported)
        } catch {
            actionError = error.localizedDescription
            Haptics.error()
        }
    }

    private func createChallenge() async {
        creatingChallenge = true
        actionError = nil
        defer { creatingChallenge = false }
        do {
            challenge = try await APIClient.shared.post("challenges", ChallengeBody(videoId: result.video.id))
            Haptics.success()
        } catch {
            actionError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func chip(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func quote(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.heavy)).kerning(1).foregroundStyle(Color.auraMuted)
            Text(text)
        }
        .padding(.leading, 12)
        .overlay(alignment: .leading) { Rectangle().fill(c1).frame(width: 3) }
    }

    @MainActor private func reveal() async {
        try? await Task.sleep(for: .milliseconds(1700))
        Haptics.thud()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { stage = 1 }
        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.spring) { stage = 2 }
        try? await Task.sleep(for: .milliseconds(600))
        withAnimation(.easeOut) { stage = 3 }
        renderShareCard()
        Reminders.requestAndSchedule()
    }

    @MainActor private func renderShareCard() {
        let renderer = ImageRenderer(content: AuraCardView(analysis: a, pseudo: pseudo, photo: peak))
        renderer.scale = 3 // 360×640 pt → 1080×1920 px (format story)
        if let image = renderer.uiImage { shareImage = Image(uiImage: image) }
    }
}

/// Puces qui passent à la ligne.
struct FlowChips: View {
    let items: [String]
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { ForEach(items, id: \.self, content: chip) }
            VStack(alignment: .leading, spacing: 8) { ForEach(items, id: \.self, content: chip) }
        }
    }
    private func chip(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.bold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().stroke(Color.auraBorder))
    }
}
