import SwiftUI

/// Révélation du score : halo + particules aux couleurs de l'aura, compteur, tier, points de ligue.
struct ResultView: View {
    let result: UploadResult
    let frames: [UIImage]
    let pseudo: String
    let onDone: () -> Void

    @State private var stage = 0
    @State private var pulse = false
    @State private var shareImage: Image?

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
                    if stage >= 2 { pointsCard.transition(.move(edge: .bottom).combined(with: .opacity)) }
                    if stage >= 3 { details.transition(.opacity) }
                    if stage >= 3 { actions }
                }
                .padding(20)
                .padding(.top, 20)
            }

            if stage >= 1 && (result.isRecord || a.auraScore >= 750) { ConfettiView(colors: [c1, c2, .auraGold, .white]) }
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
            if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview("Mon aura : \(a.auraScore)", image: shareImage)) {
                    Label("Partager ma carte d'aura", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(GlowButtonStyle(colors: [c1, c2]))
                .simultaneousGesture(TapGesture().onEnded { Analytics.track(.resultShared) })
            }
            Button("Terminer", action: onDone).buttonStyle(GhostButtonStyle())
        }
        .padding(.top, 6)
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
