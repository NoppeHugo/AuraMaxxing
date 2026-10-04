import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject private var session: SessionStore
    @State private var page = 0
    @State private var pseudo = ""
    @State private var refCode = ""
    @State private var acceptedRules = false
    @State private var isOldEnough = false
    @State private var loading = false
    @State private var error: String?
    @State private var showRules = false

    private let slides: [(emoji: String, title: String, text: String)] = [
        ("847", "T'as combien d'aura ?", "Poste une vidéo, l'IA analyse ton énergie, ton style et ta vibe, et te donne un score sur 1000."),
        ("#1", "Une ligue chaque semaine", "Tu affrontes 30 joueurs de ton niveau. Le top 7 monte de ligue, le bas du classement descend. Reset tous les lundis."),
        ("+25%", "Thème du jour, série, crew", "Colle au thème du jour pour +25 %, poste chaque jour pour un bonus de série, et monte un crew avec tes potes."),
    ]

    var body: some View {
        ZStack {
            AuraBackground(colors: [[Color.auraPurple, .auraPink, .auraCyan][min(page, 2)]], intensity: page < slides.count ? 0.5 : 0)

            VStack(spacing: 24) {
                if page < slides.count {
                    Spacer()
                    let slide = slides[page]
                    // Gros chiffre « affiche » au lieu d'un emoji.
                    Text(slide.emoji).font(.display(150))
                        .foregroundStyle([Color.auraPurple, .auraPink, .auraCyan][page])
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(slide.title.uppercased())
                        .font(.display(48))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(slide.text)
                        .font(.title3)
                        .foregroundStyle(Color.auraMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(0..<slides.count, id: \.self) { i in
                            Rectangle().fill(i == page ? Color.white : Color.white.opacity(0.25))
                                .frame(width: i == page ? 22 : 8, height: 8)
                        }
                    }
                    Button(page == slides.count - 1 ? "C'est parti" : "Suivant") {
                        Haptics.tap()
                        withAnimation(.spring) { page += 1 }
                    }
                    .buttonStyle(GlowButtonStyle())
                } else {
                    signup
                }
            }
            .padding(24)
            .id(page)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        }
        .sheet(isPresented: $showRules) { CommunityRulesView() }
    }

    private var signup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("CHOISIS TON PSEUDO")
                .font(.display(48))
            Text("C'est le nom qui apparaîtra dans les classements.")
                .foregroundStyle(Color.auraMuted)

            TextField("ex. sigma_leo", text: $pseudo)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.title3.weight(.semibold))
                .padding(16)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.auraBorder))

            // Code d'un pote ou d'un défi : rempli tout seul via le lien, ou collé depuis la page web.
            HStack(spacing: 10) {
                TextField("Code d'un pote ou d'un défi (optionnel)", text: $refCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { refCode = first.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.capsule)
                .tint(.auraPurple)
            }
            .padding(12)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))

            Toggle(isOn: $isOldEnough) { Text("J'ai 13 ans ou plus") }
            Toggle(isOn: $acceptedRules) {
                HStack(spacing: 4) {
                    Text("J'accepte les")
                    Button("règles de la communauté") { showRules = true }
                        .foregroundStyle(Color.auraCyan)
                }
            }

            if let error {
                Text(error).font(.subheadline).foregroundStyle(Color.auraRed)
            }
            Spacer()
            Button {
                Task { await submit() }
            } label: {
                if loading { ProgressView().tint(.white) } else { Text("Entrer dans l'arène") }
            }
            .buttonStyle(GlowButtonStyle())
            .disabled(loading || pseudo.count < 3 || !acceptedRules || !isOldEnough)
            .opacity(pseudo.count < 3 || !acceptedRules || !isOldEnough ? 0.5 : 1)
        }
        .toggleStyle(SwitchToggleStyle(tint: .auraPurple))
        .onAppear { if let ref = session.pendingRef { refCode = ref } }
        .onChange(of: session.pendingRef) { _, ref in if let ref { refCode = ref } }
    }

    private func submit() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            try await session.register(pseudo: pseudo.trimmingCharacters(in: .whitespaces), ref: refCode)
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }
}

/// Règles affichées à l'inscription (exigé par l'App Store pour une app avec contenu utilisateur).
struct CommunityRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("AuraMaxxing, c'est fait pour s'amuser. Tolérance zéro pour :")
                        .font(.headline)
                    ForEach([
                        "la nudité ou les contenus sexuels",
                        "la violence, les défis dangereux, les armes",
                        "le harcèlement, les moqueries sur le physique, la haine",
                        "filmer quelqu'un sans son accord",
                        "les pseudos ou noms de crew insultants",
                    ], id: \.self) { rule in
                        Label(rule, systemImage: "xmark.octagon.fill").foregroundStyle(.white)
                    }
                    Text("L'IA note le style, l'énergie et l'attitude — jamais ton physique. Les vidéos inappropriées reçoivent 0 point. Tu peux signaler ou bloquer un joueur depuis le classement (appui long). Un profil signalé plusieurs fois est masqué.")
                        .foregroundStyle(Color.auraMuted)
                    Text("Ta vidéo ne quitte jamais ton téléphone : seules quelques images sont envoyées à l'IA pour l'analyse, et AuraMaxxing ne les conserve pas (sauf la miniature de profil si tu l'acceptes). Tu peux supprimer ton compte à tout moment depuis ton profil.")
                        .foregroundStyle(Color.auraMuted)
                }
                .padding(20)
            }
            .navigationTitle("Règles")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
