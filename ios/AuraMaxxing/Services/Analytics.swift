import Foundation
import PostHog

/// Couche analytics (PostHog), même principe que VlogMe :
/// clé `POSTHOG_API_KEY` vide dans Info.plist → aucun tracking.
enum Analytics {

    enum Event: String {
        case appOpened          = "app_opened"
        case onboardingCompleted = "onboarding_completed"
        case videoPicked        = "video_picked"
        case videoAnalyzed      = "video_analyzed"
        case analysisFailed     = "analysis_failed"
        case resultShared       = "result_shared"
        case leagueViewed       = "league_viewed"
        case weekResultSeen     = "week_result_seen"
        case crewCreated        = "crew_created"
        case crewJoined         = "crew_joined"
        case crewCodeShared     = "crew_code_shared"
        case userReported       = "user_reported"
        case revealExported     = "reveal_exported"
        case revealShared       = "reveal_shared"
        case challengeShared    = "challenge_shared"
        case challengeAccepted  = "challenge_accepted"
        case inviteShared       = "invite_shared"
    }

    private static var isEnabled = false

    static func configure() {
        guard
            let key = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String,
            !key.isEmpty,
            !key.hasPrefix("$(")
        else { return }
        let host = (Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String)
            .flatMap { $0.isEmpty ? nil : $0 } ?? "https://eu.i.posthog.com"
        let config = PostHogConfig(apiKey: key, host: host)
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
        isEnabled = true
    }

    static func identify(_ userId: String) {
        guard isEnabled else { return }
        PostHogSDK.shared.identify(userId)
    }

    static func track(_ event: Event, _ properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }
}
