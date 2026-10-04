import SwiftUI

@main
struct AuraMaxxingApp: App {

    @StateObject private var session = SessionStore()

    init() {
        Analytics.configure()
        Analytics.track(.appOpened)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
                .tint(.auraPurple)
        }
    }
}
