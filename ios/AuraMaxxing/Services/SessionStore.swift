import Foundation

/// État global : session du joueur + profil (ligue, semaine, thème du jour, série…).
@MainActor
final class SessionStore: ObservableObject {

    @Published private(set) var isLoggedIn: Bool
    @Published private(set) var profile: Profile?
    @Published var errorMessage: String?

    private let api = APIClient.shared

    init() {
        let token = KeychainStore.load()
        isLoggedIn = token != nil
        api.token = token
    }

    func register(pseudo: String) async throws {
        let response: RegisterResponse = try await api.post("register", RegisterBody(pseudo: pseudo))
        KeychainStore.save(response.token)
        api.token = response.token
        isLoggedIn = true
        Analytics.identify(response.user.id)
        Analytics.track(.onboardingCompleted)
        await refresh()
    }

    func refresh() async {
        guard isLoggedIn else { return }
        do {
            profile = try await api.get("me")
        } catch APIError.unauthorized {
            logout()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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
        isLoggedIn = false
    }
}
