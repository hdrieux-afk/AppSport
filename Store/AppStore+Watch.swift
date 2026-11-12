// AppStore+Watch.swift
// Envoi des séances vers la montre sans câble, par intervals.icu puis Garmin Connect.
// La clé d'API est dans le Trousseau, l'identifiant dans les réglages. Les séances de muscu ne sont pas envoyées.

import Foundation

extension AppStore {

    private static let keyAccount = "intervalsAPIKey"
    private static let idDefaultsKey = "intervalsAthleteID"

    // MARK: - Connexion

    func refreshWatchState() {
        watchAthleteID = UserDefaults.standard.string(forKey: AppStore.idDefaultsKey) ?? ""
        watchConnected = !watchAthleteID.isEmpty && KeychainStore.load(AppStore.keyAccount) != nil
    }

    private func makeClient() -> IntervalsClient? {
        guard let key = KeychainStore.load(AppStore.keyAccount), !watchAthleteID.isEmpty else { return nil }
        return IntervalsClient(athleteID: watchAthleteID, apiKey: key)
    }

    /// Teste l'identifiant et la clé, puis les enregistre.
    @MainActor
    func connectWatch(athleteID: String, apiKey: String) async {
        watchBusy = true
        watchMessage = nil
        defer { watchBusy = false }
        let id = athleteID.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let name = try await IntervalsClient(athleteID: id, apiKey: key).testConnection()
            KeychainStore.save(key, account: AppStore.keyAccount)
            UserDefaults.standard.set(id, forKey: AppStore.idDefaultsKey)
            refreshWatchState()
            watchMessage = "Connecté : \(name)."
        } catch {
            watchMessage = watchErrorText(error)
        }
    }

    func disconnectWatch() {
        KeychainStore.delete(AppStore.keyAccount)
        UserDefaults.standard.removeObject(forKey: AppStore.idDefaultsKey)
        refreshWatchState()
        watchMessage = nil
    }

    // MARK: - Envoi

    /// Envoie (ou met à jour) une séance dans le calendrier d'intervals.icu.
    @MainActor
    func sendToWatch(_ id: UUID) async {
        guard let client = makeClient(), let profile = profile, let session = session(id) else { return }
        watchBusy = true
        defer { watchBusy = false }
        do {
            if let eventID = try await push(session, client: client, profile: profile) {
                setEventID(eventID, for: id)
                watchMessage = "Séance envoyée. Elle arrive sur la montre à la prochaine synchronisation de Garmin Connect."
            } else {
                watchMessage = "Une séance de muscu n'a pas de format pour la montre."
            }
        } catch {
            watchMessage = watchErrorText(error)
        }
    }

    /// Envoie les séances des prochains jours, après avoir supprimé de intervals.icu celles de l'app qui ne sont plus au plan.
    @MainActor
    func sendUpcomingToWatch(days: Int = 14) async {
        guard let client = makeClient(), let profile = profile else { return }
        watchBusy = true
        watchMessage = nil
        defer { watchBusy = false }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: days, to: start) ?? start
        let upcoming = weeks.flatMap { $0.sessions }.filter {
            $0.date >= start && $0.date < end && $0.status != .cancelled && !$0.isDone
        }

        do {
            let known = Set(upcoming.map { IntervalsExport.externalID(for: $0.id) })
            let remote = try await client.events(from: start, to: end)
            for event in remote where event.externalID.hasPrefix(IntervalsExport.externalPrefix)
                && !known.contains(event.externalID) {
                try await client.delete(eventID: event.id)
            }
            var sent = 0
            for session in upcoming {
                if let eventID = try await push(session, client: client, profile: profile) {
                    setEventID(eventID, for: session.id)
                    sent += 1
                }
            }
            watchMessage = "\(sent) séance(s) envoyée(s) pour les \(days) prochains jours."
        } catch {
            watchMessage = watchErrorText(error)
        }
    }

    /// Après une modification, un déplacement ou une annulation : met à jour ou supprime la séance déjà envoyée.
    func watchRefresh(_ id: UUID) {
        guard watchConnected, let session = session(id), session.intervalsEventID != nil else { return }
        Task { await refreshWatchEvent(id) }
    }

    @MainActor
    private func refreshWatchEvent(_ id: UUID) async {
        guard let client = makeClient(), let profile = profile,
              let session = session(id), let eventID = session.intervalsEventID else { return }
        do {
            if session.status == .cancelled || session.kind.sport == .strength {
                try await client.delete(eventID: eventID)
                setEventID(nil, for: id)
            } else if let newID = try await push(session, client: client, profile: profile) {
                setEventID(newID, for: id)
            }
            watchMessage = "Calendrier intervals.icu mis à jour."
        } catch {
            watchMessage = watchErrorText(error)
        }
    }

    // MARK: - Interne

    /// Crée l'événement, ou le met à jour s'il existe déjà. Renvoie nil pour une séance sans format montre.
    private func push(_ session: TrainingSession, client: IntervalsClient, profile: AthleteProfile) async throws -> Int? {
        guard case .endurance(let workout) = session.render(profile: profile, goal: goal),
              let payload = IntervalsExport.payload(for: session, workout: workout,
                                                    name: session.kind.title, maxHR: profile.maxHR) else {
            return nil
        }
        if let existing = session.intervalsEventID {
            do {
                try await client.update(eventID: existing, payload: payload)
                return existing
            } catch IntervalsError.notFound {
                // L'événement a été supprimé côté intervals.icu : on le recrée.
            }
        }
        return try await client.create(payload)
    }

    private func watchErrorText(_ error: Error) -> String {
        guard let failure = error as? IntervalsError else {
            return "Erreur inattendue : \(error.localizedDescription)"
        }
        switch failure {
        case .invalidID:
            return "Identifiant invalide. Il ressemble à i123456, avec le « i » devant."
        case .invalidCredentials:
            return "Identifiant ou clé refusés par intervals.icu. Vérifiez le « i » devant l'identifiant et recopiez la clé."
        case .notFound:
            return "Élément introuvable sur intervals.icu."
        case .rateLimited:
            return "Trop de requêtes : réessayez dans une minute."
        case .http(let code, _):
            return "intervals.icu a répondu avec l'erreur \(code)."
        case .network(let text):
            return "Problème de connexion : \(text)"
        case .unexpectedResponse:
            return "Réponse inattendue d'intervals.icu."
        }
    }
}
