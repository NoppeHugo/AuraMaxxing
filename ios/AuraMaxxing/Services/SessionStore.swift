import Foundation
import WidgetKit

/// État global : session du joueur + profil (ligue, semaine, thème du jour, série…)
/// + liens entrants (défi, invitation) + mise à jour du widget.
@MainActor
final class SessionStore: ObservableObject {

    @Published private(set) var isLoggedIn: Bool
    @Published private(set) var profile: Profile?
    @Published var errorMessage: String?
    /// Demande d'ouverture de l'onglet Ligue (tap sur le widget).
    @Published var openLeagueRequest = 0
    /// Défi reçu par lien, à relever depuis l'accueil.
    @Published var pendingChallenge: ChallengeInfo?
    /// Code de parrainage (défi ou pseudo du pote) à utiliser à l'inscription.
    @Published var pendingRef: String? {
        didSet { UserDefaults.standard.set(pendingRef, forKey: "pending-ref") }
    }

    private let api = APIClient.shared

    init() {
        let token = KeychainStore.load()
        isLoggedIn = token != nil
        pendingRef = UserDefaults.standard.string(forKey: "pending-ref")
        api.token = token
    }

    func register(pseudo: String, ref: String?) async throws {
        let cleanRef = ref?.trimmingCharacters(in: .whitespacesAndNewlines)
        let response: RegisterResponse = try await api.post(
            "register", RegisterBody(pseudo: pseudo, ref: cleanRef?.isEmpty == false ? cleanRef : nil)
        )
        KeychainStore.save(response.token)
        api.token = response.token
        isLoggedIn = true
        Analytics.identify(response.user.id)
        Analytics.track(.onboardingCompleted, ["invited": response.invitedBy != nil])
        // Inscrit via un lien de défi : on propose de le relever tout de suite.
        if let code = cleanRef, code.count == 6 { await loadChallenge(code) }
        pendingRef = nil
        await refresh()
    }

    func refresh() async {
        guard isLoggedIn else { return }
        do {
            let p: Profile = try await api.get("me")
            profile = p
            updateWidget(p)
        } catch APIError.unauthorized {
            logout()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Liens entrants

    /// auramaxxing://challenge/K7XP2M · auramaxxing://invite/leo_sigma
    /// (et https://…/d/K7XP2M · https://…/i/leo_sigma si les liens universels sont activés)
    func handle(url: URL) {
        let parts = (url.scheme == "auramaxxing" ? [url.host ?? ""] + url.pathComponents : url.pathComponents)
            .filter { $0 != "/" && !$0.isEmpty }
        if parts.first == "league" { openLeagueRequest += 1; return }
        guard parts.count >= 2 else { return }
        let kind = parts[0], value = parts[1]
        switch kind {
        case "challenge", "d":
            pendingRef = isLoggedIn ? nil : value.uppercased()
            if isLoggedIn { Task { await loadChallenge(value) } }
        case "invite", "i":
            if !isLoggedIn { pendingRef = value }
        default:
            break
        }
    }

    func loadChallenge(_ code: String) async {
        let info: ChallengeInfo? = try? await api.get("challenges/\(code.uppercased())")
        // On ne propose pas de relever son propre défi.
        if let info, info.from?.pseudo != profile?.user.pseudo, !info.expired { pendingChallenge = info }
    }

    // MARK: - Compte

    func markResultSeen() async {
        let _: OkResponse? = try? await api.post("result-seen", EmptyBody())
        await refresh()
    }

    func deleteAccount() async {
        let _: OkResponse? = try? await api.delete("me")
        logout()
    }

    func logout() {
        KeychainStore.delete()
        api.token = nil
        profile = nil
        pendingChallenge = nil
        isLoggedIn = false
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Widget

    private func updateWidget(_ p: Profile) {
        WidgetSnapshot(
            pseudo: p.user.pseudo,
            leagueEmoji: p.league.emoji,
            leagueName: p.league.name,
            leagueColor: p.league.color,
            rank: p.week.rank,
            size: p.week.size ?? 0,
            points: p.week.points ?? 0,
            streak: p.streak.days,
            weekEndsAt: p.week.endDate,
            theme: p.today.theme,
            aheadPseudo: p.rivals.ahead?.pseudo,
            aheadGap: p.rivals.ahead?.gap
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
