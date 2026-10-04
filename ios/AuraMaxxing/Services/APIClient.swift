import Foundation

enum APIError: LocalizedError {
    case server(String)
    case unauthorized
    case network

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .unauthorized: return "Session expirée, reconnecte-toi."
        case .network: return "Pas de connexion. Vérifie ton réseau et réessaie."
        }
    }
}

/// Client HTTP du backend AuraMaxxing (async/await, JSON).
final class APIClient {

    static let shared = APIClient()

    /// Jeton de session (stocké dans le trousseau par SessionStore).
    var token: String?

    private let baseURL: URL = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "AURA_API_URL") as? String
        return URL(string: raw?.isEmpty == false ? raw! : "http://localhost:3000")!
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120 // l'analyse IA peut prendre quelques dizaines de secondes
        return URLSession(configuration: config)
    }()

    private struct ErrorBody: Decodable { let error: String }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await send(path, method: "GET", body: Optional<EmptyBody>.none)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, _ body: B) async throws -> T {
        try await send(path, method: "POST", body: body)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await send(path, method: "DELETE", body: Optional<EmptyBody>.none)
    }

    private func send<T: Decodable, B: Encodable>(_ path: String, method: String, body: B?) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/v1").appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONEncoder().encode(body) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else {
            let message = (try? decoder.decode(ErrorBody.self, from: data))?.error ?? "Erreur serveur (\(status))."
            throw APIError.server(message)
        }
        return try decoder.decode(T.self, from: data)
    }
}
