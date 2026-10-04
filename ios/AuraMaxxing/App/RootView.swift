import SwiftUI

struct RootView: View {

    @EnvironmentObject private var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: Tab = .home

    enum Tab { case home, league, crew, profile }

    var body: some View {
        Group {
            if session.isLoggedIn {
                TabView(selection: $tab) {
                    HomeView(openLeague: { tab = .league })
                        .tabItem { Label("Aura", systemImage: "sparkles") }
                        .tag(Tab.home)
                    LeagueView()
                        .tabItem { Label("Ligue", systemImage: "trophy.fill") }
                        .tag(Tab.league)
                    CrewView()
                        .tabItem { Label("Crew", systemImage: "person.3.fill") }
                        .tag(Tab.crew)
                    ProfileView()
                        .tabItem { Label("Profil", systemImage: "person.crop.circle") }
                        .tag(Tab.profile)
                }
                .toolbarBackground(Color.auraBackground, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .task { await session.refresh() }
                .onChange(of: session.openLeagueRequest) { _, _ in tab = .league }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await session.refresh() } }
                }
                // Résultat de la semaine passée (montée / descente) : moment fort, affiché une fois.
                .fullScreenCover(item: Binding(
                    get: { session.profile?.lastResult },
                    set: { if $0 == nil { Task { await session.markResultSeen() } } }
                )) { result in
                    WeekResultView(result: result)
                }
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut, value: session.isLoggedIn)
    }
}

extension WeekResult: Identifiable {
    var id: String { week }
}
