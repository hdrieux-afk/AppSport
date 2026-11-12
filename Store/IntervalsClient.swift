// IntervalsClient.swift
// Appels à l'API d'intervals.icu (authentification simple : identifiant "API_KEY", mot de passe = clé personnelle).
//   GET    /api/v1/athlete/{id}                    test de la connexion
//   GET    /api/v1/athlete/{id}/events             liste des événements d'une période
//   POST   /api/v1/athlete/{id}/events             crée une séance planifiée
//   PUT    /api/v1/athlete/{id}/events/{eventId}   met à jour une séance
//   DELETE /api/v1/athlete/{id}/events/{eventId}   supprime une séance

import Foundation

enum IntervalsError: Error {
    case invalidID
    case invalidCredentials
    case notFound
    case rateLimited
    case http(Int, String)
    case network(String)
    case unexpectedResponse
}

struct IntervalsEventRef {
    let id: Int
    let externalID: String
}

struct IntervalsClient {
    let athleteID: String
    let apiKey: String

    // MARK: - Opérations

    /// Vérifie l'identifiant et la clé ; renvoie le nom du compte.
    func testConnection() async throws -> String {
        let data = try await send(try makeRequest("", method: "GET"))
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return (object?["name"] as? String) ?? athleteID
    }

    func create(_ payload: IntervalsEventPayload) async throws -> Int {
        let body = try JSONEncoder().encode(payload)
        let data = try await send(try makeRequest("/events", method: "POST", body: body))
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let id = object["id"] as? Int else { throw IntervalsError.unexpectedResponse }
        return id
    }

    func update(eventID: Int, payload: IntervalsEventPayload) async throws {
        let body = try JSONEncoder().encode(payload)
        _ = try await send(try makeRequest("/events/\(eventID)", method: "PUT", body: body))
    }

    func delete(eventID: Int) async throws {
        _ = try await send(try makeRequest("/events/\(eventID)", method: "DELETE"))
    }

    /// Événements du calendrier entre deux dates (jours locaux), réduits à leur identifiant et leur identifiant externe.
    func events(from start: Date, to end: Date) async throws -> [IntervalsEventRef] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let query = [URLQueryItem(name: "oldest", value: formatter.string(from: start)),
                     URLQueryItem(name: "newest", value: formatter.string(from: end))]
        let data = try await send(try makeRequest("/events", method: "GET", query: query))
        let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
        return list.compactMap { item in
            guard let id = item["id"] as? Int, let external = item["external_id"] as? String else { return nil }
            return IntervalsEventRef(id: id, externalID: external)
        }
    }

    // MARK: - Requêtes

    private func makeRequest(_ path: String, method: String, query: [URLQueryItem] = [],
                             body: Data? = nil) throws -> URLRequest {
        guard !athleteID.isEmpty, athleteID.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw IntervalsError.invalidID
        }
        var components = URLComponents(string: "https://intervals.icu/api/v1/athlete/\(athleteID)\(path)")
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw IntervalsError.invalidID }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        let token = Data("API_KEY:\(apiKey)".utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw IntervalsError.unexpectedResponse }
            switch http.statusCode {
            case 200..<300: return data
            case 401, 403: throw IntervalsError.invalidCredentials
            case 404: throw IntervalsError.notFound
            case 429: throw IntervalsError.rateLimited
            default: throw IntervalsError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
            }
        } catch let error as IntervalsError {
            throw error
        } catch {
            throw IntervalsError.network(error.localizedDescription)
        }
    }
}
