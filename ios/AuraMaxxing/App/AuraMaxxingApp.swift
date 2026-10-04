import SwiftUI

@main
struct AuraMaxxingApp: App {

    @StateObject private var session = SessionStore()

    init() {
        NavigationStyle.apply()
        Analytics.configure()
        Analytics.track(.appOpened)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
                .tint(.auraPurple)
                // Liens de défi / d'invitation (auramaxxing://challenge/CODE, auramaxxing://invite/PSEUDO)
                .onOpenURL { session.handle(url: $0) }
        }
    }
}
