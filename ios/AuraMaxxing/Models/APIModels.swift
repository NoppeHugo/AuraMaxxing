import Foundation

// Miroir des réponses JSON du backend (app/api/v1/*).
// Le décodeur convertit le snake_case (aura_score → auraScore).

struct LeagueInfo: Codable, Hashable {
    var index: Int?
    let name: String
    let emoji: String
    let color: String
}

struct Stats: Codable, Hashable {
    let drip: Int
    let vibe: Int
    let confiance: Int
    let originalite: Int
    let trendFit: Int

    /// Ordre et libellés d'affichage.
    var rows: [(label: String, value: Int)] {
        [("Drip", drip), ("Vibe", vibe), ("Confiance", confiance), ("Originalité", originalite), ("Trend fit", trendFit)]
    }
}

/// Un joueur tel qu'il apparaît dans les classements (champs optionnels selon la liste).
struct Player: Codable, Hashable, Identifiable {
    let id: String
    let pseudo: String
    let league: Int
    let tier: String
    let title: String
    let emoji: String
    let auraColor: String
    let auraColor2: String
    let cover: String?
    let bestScore: Int
    let streak: Int
    // Classement de ligue
    var rank: Int?
    var points: Int?
    var zone: Zone?
    var isMe: Bool?
    // Top monde / légendes
    var score: Int?
    var week: String?
    var label: String?

    enum Zone: String, Codable { case up, down, stay }

    /// Identifiant unique de ligne (un même joueur peut apparaître plusieurs semaines chez les légendes).
    var rowID: String { "\(id)-\(week ?? "")" }
}

struct WeekStatus: Codable, Hashable {
    let id: String
    let label: String
    let endsAt: Double
    var points: Int?
    var rank: Int?
    var size: Int?

    var endDate: Date { Date(timeIntervalSince1970: endsAt / 1000) }
}

struct Today: Codable, Hashable {
    let theme: String
    let hint: String
    let hashtag: String
    let uploadsLeft: Int
    let uploadsMax: Int
    let resetsAt: Double
    let postedToday: Bool
}

struct Streak: Codable, Hashable {
    let days: Int
    let bonus: Double
}

struct WeekResult: Codable, Hashable {
    let week: String
    let league: Int
    let newLeague: Int
    let rank: Int
    let size: Int
    let points: Int
    let outcome: Outcome
    let leagueInfo: LeagueInfo

    enum Outcome: String, Codable { case up, down, stay }
}

struct CrewRef: Codable, Hashable {
    let id: String
    let name: String
    let code: String
}

struct Badge: Codable, Hashable {
    let week: String
    let label: String
}

struct VideoRecord: Codable, Hashable, Identifiable {
    let id: String
    let week: String
    let day: String
    let score: Int
    let points: Int
    let themeMatch: Bool
    let streakBonus: Double
    let tier: String
    let title: String
    let emoji: String
    let trends: [String]
    let stats: Stats
    let createdAt: Double
}

struct Profile: Codable {
    let user: Player
    let league: LeagueInfo
    let week: WeekStatus
    let today: Today
    let streak: Streak
    let lastResult: WeekResult?
    let crew: CrewRef?
    let rivals: Rivals
    let invite: Invite
    let badges: [Badge]
    let stats: ProfileStats
    let recent: [VideoRecord]

    struct ProfileStats: Codable { let videos: Int; let bestScore: Int }
}

struct RegisterResponse: Codable {
    let token: String
    let user: Player
    let invitedBy: String?
}

/// Le joueur juste devant moi + ceux qui m'ont dépassé depuis ma dernière visite de la ligue.
struct Rivals: Codable, Hashable {
    let ahead: Ahead?
    let overtakenBy: [String]
    struct Ahead: Codable, Hashable { let pseudo: String; let gap: Int }
}

/// Parrainage : chaque pote qui joue donne +1 vidéo par jour (plafonné).
struct Invite: Codable, Hashable {
    let code: String
    let url: String
    let invited: Int
    let active: Int
    let bonus: Int
    let max: Int
}

// MARK: - Défis 1v1

struct ChallengeInfo: Codable, Hashable, Identifiable {
    let code: String
    let from: ChallengeFrom?
    let score: Int
    let tier: String
    let title: String
    let emoji: String
    let auraColor: String
    let auraColor2: String
    let expiresAt: Double
    let expired: Bool
    let answers: Int
    let beaten: Int
    // Création
    var url: String?
    var shareText: String?
    // Mes défis envoyés / reçus
    var results: [ChallengeAnswer]?
    var myScore: Int?
    var won: Bool?

    var id: String { code }

    struct ChallengeFrom: Codable, Hashable { let pseudo: String; let league: LeagueInfo }
    struct ChallengeAnswer: Codable, Hashable { let pseudo: String; let score: Int; let won: Bool }
}

struct MyChallenges: Codable {
    let sent: [ChallengeInfo]
    let received: [ChallengeInfo]
}

/// Résultat d'une réponse à un défi (renvoyé avec l'analyse).
struct ChallengeOutcome: Codable, Hashable {
    let code: String
    let opponent: String
    let opponentScore: Int
    let myScore: Int
    let won: Bool
}

struct LeagueBoard: Codable {
    let week: WeekStatus
    let league: LeagueInfo
    let leagues: [LeagueInfo]
    let joined: Bool
    let zones: Zones
    let entries: [Player]

    struct Zones: Codable { let promote: Int; let demote: Int }
}

struct WorldBoard: Codable {
    let week: WeekStatus
    let topVideos: [Player]
    let legends: [Player]
}

struct CrewBoard: Codable {
    let week: WeekStatus
    let crew: MyCrew?
    let top: [CrewRow]
    let schools: [CrewRow]
    let city: CityRanking?

    struct CityRanking: Codable { let name: String; let crews: [CrewRow] }

    struct MyCrew: Codable {
        let id: String
        let name: String
        let code: String
        let kind: String
        let city: String?
        let rank: Int
        let points: Int
        let members: [Player]
    }

    struct CrewRow: Codable, Identifiable {
        let id: String
        let name: String
        let members: Int
        let points: Int
        let rank: Int
        let isMine: Bool
        let kind: String
        let city: String?
    }
}

struct VideoAura: Codable, Hashable {
    let auraScore: Int
    let tier: String
    let title: String
    let emoji: String
    let auraColor: String
    let auraColor2: String
    let stats: Stats
    let trends: [Trend]
    let hype: String
    let roast: String
    let tips: [String]
    let contentOk: Bool
    let themeMatch: Bool
    let peakFrame: Int
    let peakMoment: String

    struct Trend: Codable, Hashable { let name: String; let confidence: Int }
}

struct UploadResult: Codable {
    let analysis: VideoAura
    let video: VideoRecord
    let isRecord: Bool
    let counted: Bool
    let weekPoints: Int
    let gained: Int
    let rankBefore: Int?
    let rankAfter: Int
    let lobbySize: Int
    let streak: Int
    let uploadsLeft: Int
    let challenge: ChallengeOutcome?
}

// MARK: - Corps de requêtes

struct RegisterBody: Encodable { let pseudo: String; let ref: String? }
struct CrewNameBody: Encodable { let name: String; let kind: String; let city: String }
struct ChallengeBody: Encodable { let videoId: String }
struct CrewCodeBody: Encodable { let code: String }
struct UserIdBody: Encodable { let userId: String }
struct EmptyBody: Encodable {}
struct OkResponse: Codable { let ok: Bool }

struct VideoBody: Encodable {
    let frames: [String]
    let timestamps: [Double]
    let duration: Double
    let caption: String
    let coverConsent: Bool
    let cover: String?
    let challengeCode: String?
}
