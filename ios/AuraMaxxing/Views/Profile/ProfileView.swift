import SwiftUI

/// Profil : meilleur score, badges de saison, réglages et suppression du compte.
struct ProfileView: View {

    @EnvironmentObject private var session: SessionStore
    @State private var confirmDelete = false
    @State private var showRules = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.auraBackground.ignoresSafeArea()
                ScrollView {
                    if let p = session.profile {
                        VStack(spacing: 16) {
                            header(p)
                            badges(p)
                            settings
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("PROFIL")
        }
        .sheet(isPresented: $showRules) { CommunityRulesView() }
        .confirmationDialog("Supprimer ton compte ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer définitivement", role: .destructive) { Task { await session.deleteAccount() } }
        } message: {
            Text("Ton pseudo, tes scores, tes badges et ta place dans les classements seront effacés.")
        }
    }

    private func header(_ p: Profile) -> some View {
        VStack(spacing: 10) {
            AvatarView(player: p.user, size: 104)
                .background(Circle().fill(Color(hex: p.user.auraColor2)).offset(x: 6, y: 6))
                .padding(.top, 8)
            Text(p.user.pseudo.uppercased()).font(.display(42))
            if !p.user.title.isEmpty {
                Text(p.user.title).foregroundStyle(Color.auraMuted)
            }
            LeagueBadge(league: p.league)
            HStack(spacing: 0) {
                stat("\(p.stats.bestScore)", "record d'aura")
                stat("\(p.stats.videos)", "vidéos")
                stat("\(p.streak.days)", "série")
            }
            .auraCard()
        }
    }

    private func badges(_ p: Profile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Badges de saison").font(.headline)
            if p.badges.isEmpty {
                Text("Finis #1 de ton groupe un dimanche soir pour décrocher ton premier badge.")
                    .font(.subheadline).foregroundStyle(Color.auraMuted)
            } else {
                ForEach(p.badges, id: \.self) { Text($0.label).font(.subheadline.weight(.bold)) }
            }
        }
        .auraCard()
    }

    private var settings: some View {
        VStack(spacing: 0) {
            Button { showRules = true } label: { settingRow("Règles de la communauté", "shield.lefthalf.filled") }
            Divider().overlay(Color.auraBorder)
            Button { Reminders.requestAndSchedule() } label: { settingRow("Activer les rappels", "bell.badge") }
            Divider().overlay(Color.auraBorder)
            Button { session.logout() } label: { settingRow("Se déconnecter", "rectangle.portrait.and.arrow.right") }
            Divider().overlay(Color.auraBorder)
            Button(role: .destructive) { confirmDelete = true } label: {
                settingRow("Supprimer mon compte", "trash").foregroundStyle(Color.auraRed)
            }
        }
        .buttonStyle(.plain)
        .auraCard(padding: 4)
    }

    private func settingRow(_ title: String, _ icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.auraMuted)
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.black)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Color.auraMuted)
        }
        .frame(maxWidth: .infinity)
    }
}
