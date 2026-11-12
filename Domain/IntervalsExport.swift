// IntervalsExport.swift
// Conversion d'une séance d'endurance en texte au format de l'éditeur de séances d'intervals.icu,
// et en requête JSON pour créer un événement "séance" dans son calendrier.
// intervals.icu transmet ensuite les séances à Garmin Connect (option "Upload planned workouts").
//
// Format (documentation d'intervals.icu) :
//   - une étape = "- durée cible" ; durées 15m, 30s, 1m30 ; distances 0.2km (m = minutes, jamais mètres)
//   - cibles : "65-75% HR" (pourcentage de la FC max), "4:33-5:00/km Pace" (allure absolue)
//   - répétitions : un titre se terminant par "3x" ; les répétitions imbriquées ne sont pas permises

import Foundation

struct IntervalsEventPayload: Encodable {
    var category: String = "WORKOUT"
    var startDateLocal: String
    var type: String
    var name: String
    var description: String
    var externalId: String

    enum CodingKeys: String, CodingKey {
        case category
        case startDateLocal = "start_date_local"
        case type, name, description
        case externalId = "external_id"
    }
}

enum IntervalsExport {

    /// Préfixe des identifiants externes : permet de retrouver, dans le calendrier d'intervals.icu,
    /// les séances créées par l'app (et seulement elles).
    static let externalPrefix = "appsport-"

    static func externalID(for sessionID: UUID) -> String {
        externalPrefix + sessionID.uuidString.lowercased()
    }

    /// Type d'activité côté intervals.icu. La muscu n'a pas de format pour la montre : aucun envoi.
    static func activityType(for sport: Sport) -> String? {
        switch sport {
        case .run: return "Run"
        case .bike: return "Ride"
        case .strength: return nil
        }
    }

    /// Requête de création ou de mise à jour de l'événement. Renvoie nil pour une séance de muscu.
    static func payload(for session: TrainingSession, workout: EnduranceWorkout, name: String,
                        maxHR: Int, calendar: Calendar = .current) -> IntervalsEventPayload? {
        guard let type = activityType(for: session.kind.sport) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'00:00:00"
        return IntervalsEventPayload(startDateLocal: formatter.string(from: session.date),
                                     type: type,
                                     name: name,
                                     description: workoutText(workout, maxHR: maxHR),
                                     externalId: externalID(for: session.id))
    }

    /// Texte des étapes. La FC est convertie en pourcentage de la FC max (à renseigner aussi dans intervals.icu).
    static func workoutText(_ workout: EnduranceWorkout, maxHR: Int) -> String {
        var lines: [String] = []
        var currentSection = ""

        func open(_ section: String) {
            if section != currentSection {
                if !lines.isEmpty { lines.append("") }
                lines.append(section)
                currentSection = section
            }
        }

        for item in workout.items {
            switch item {
            case .step(let step):
                switch step.intensity {
                case .warmup: open("Échauffement")
                case .cooldown: open("Retour au calme")
                default: open("Corps de séance")
                }
                lines.append(stepLine(step, maxHR: maxHR))
            case .repeatBlock(let count, let steps):
                currentSection = ""
                if !lines.isEmpty { lines.append("") }
                lines.append("Série \(count)x")
                currentSection = "Série \(count)x"
                for step in steps { lines.append(stepLine(step, maxHR: maxHR)) }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Détails de format

    private static func stepLine(_ step: WorkoutStep, maxHR: Int) -> String {
        "- \(durationText(step.duration)) \(targetText(step.target, maxHR: maxHR))"
    }

    private static func durationText(_ duration: StepDuration) -> String {
        switch duration {
        case .time(let seconds):
            if seconds < 60 { return "\(seconds)s" }
            let minutes = seconds / 60
            let rest = seconds % 60
            return rest == 0 ? "\(minutes)m" : "\(minutes)m\(rest)"
        case .distance(let meters):
            return String(format: "%g", Double(meters) / 1000) + "km"
        case .open:
            return "5m"
        }
    }

    private static func targetText(_ target: StepTarget, maxHR: Int) -> String {
        switch target {
        case .pace(let minMps, let maxMps):
            return "\(paceText(maxMps))-\(paceText(minMps))/km Pace"
        case .heartRate(let minBpm, let maxBpm):
            return "\(percent(minBpm, of: maxHR))-\(percent(maxBpm, of: maxHR))% HR"
        case .open:
            // intervals.icu veut une cible à chaque étape : plage de FC douce pour les étapes libres.
            return "50-65% HR"
        }
    }

    private static func percent(_ bpm: Int, of maxHR: Int) -> Int {
        guard maxHR > 0 else { return 0 }
        return Int((Double(bpm) / Double(maxHR) * 100).rounded())
    }

    private static func paceText(_ metersPerSecond: Double) -> String {
        guard metersPerSecond > 0 else { return "0:00" }
        let total = Int((1000 / metersPerSecond).rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
