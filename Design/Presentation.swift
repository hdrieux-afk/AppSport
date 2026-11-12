// Presentation.swift
// Tout ce qui transforme le domaine en texte lisible pour l'utilisateur (en français).
// Le domaine reste sans texte d'interface : on peut changer de langue ici sans toucher aux règles.

import SwiftUI

extension StrengthFocus {
    var title: String {
        switch self {
        case .fullBody: return "full body"
        case .legs: return "jambes"
        case .push: return "push"
        case .pull: return "pull"
        }
    }
}

extension SessionKind {
    var title: String {
        switch self {
        case .run(let type):
            return type.title
        case .bike:
            return "Sortie vélo"
        case .strength(let focus, let venue):
            return "Muscu \(focus.title), \(venue == .home ? "maison" : "salle")"
        }
    }

    /// Durée proposée quand l'utilisateur ajoute une séance à la main.
    var defaultDuration: Int {
        switch self {
        case .run(let type):
            switch type {
            case .easyRun: return 45
            case .shortIntervals: return 40
            case .longIntervals: return 55
            case .longRun: return 80
            }
        case .bike: return 60
        case .strength: return 45
        }
    }

    /// Toutes les séances proposables (changer de sport, ajouter une séance).
    static func choices(venue: Venue) -> [SessionKind] {
        let runs = RunSessionType.allCases.map { SessionKind.run($0) }
        let strength = StrengthFocus.allCases.map { SessionKind.strength($0, venue) }
        return runs + [SessionKind.bike] + strength
    }
}

extension PlanPhase {
    var label: String {
        switch self {
        case .base: return "base"
        case .development: return "développement"
        case .specific: return "spécifique"
        case .taper: return "affûtage"
        }
    }
}

extension RaceDistance {
    var label: String {
        switch self {
        case .fiveK: return "5 km"
        case .tenK: return "10 km"
        case .half: return "Semi-marathon"
        case .marathon: return "Marathon"
        }
    }
}

extension Feasibility {
    var label: String {
        switch self {
        case .cautious: return "Prudent"
        case .realistic: return "Réaliste"
        case .ambitious: return "Ambitieux"
        case .veryAmbitious: return "Très ambitieux"
        }
    }

    var color: Color {
        switch self {
        case .cautious: return Theme.muted
        case .realistic: return Theme.sage
        case .ambitious: return Color(hex: 0xE0A98F)
        case .veryAmbitious: return Theme.terracotta
        }
    }
}

extension StepIntensity {
    var label: String {
        switch self {
        case .warmup: return "Échauffement"
        case .active: return "Effort"
        case .recovery: return "Récupération"
        case .rest: return "Repos"
        case .cooldown: return "Retour au calme"
        }
    }

    /// L'intensité se lit comme une teinte plus ou moins forte de la couleur du sport.
    var opacity: Double {
        switch self {
        case .active: return 1.0
        case .warmup, .cooldown: return 0.55
        case .recovery: return 0.30
        case .rest: return 0.20
        }
    }
}

extension RepScheme {
    var text: String {
        switch self {
        case .reps(let n): return "\(n)"
        case .repsPerSide(let n): return "\(n) par jambe"
        case .toFailureMinus(let n): return "max moins \(n)"
        case .seconds(let n): return "\(n) s"
        }
    }
}

/// Allure en minutes par kilomètre à partir d'une vitesse en m/s : 3,70 m/s donne "4:30".
func formatPace(_ metersPerSecond: Double) -> String {
    guard metersPerSecond > 0 else { return "-" }
    let total = Int((1000 / metersPerSecond).rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}

/// Durée totale en h:mm:ss ou mm:ss.
func formatClock(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

func describe(_ duration: StepDuration) -> String {
    switch duration {
    case .time(let s):
        if s < 60 { return "\(s) s" }
        return s % 60 == 0 ? "\(s / 60) min" : "\(s / 60) min \(s % 60) s"
    case .distance(let m):
        return m % 1000 == 0 ? "\(m / 1000) km" : "\(m) m"
    case .open:
        return "Jusqu'au bouton lap"
    }
}

func describe(_ target: StepTarget) -> String {
    switch target {
    case .pace(let lo, let hi):
        // La vitesse la plus haute correspond à l'allure la plus rapide, donc au plus petit temps au km.
        return "\(formatPace(hi))–\(formatPace(lo)) /km"
    case .heartRate(let lo, let hi):
        return "\(lo)–\(hi) bpm"
    case .open:
        return "Libre"
    }
}

extension EnduranceWorkout {
    /// Segments à plat, avec une durée estimée en secondes, pour dessiner le profil de la séance.
    var segments: [(intensity: StepIntensity, seconds: Double)] {
        var out: [(intensity: StepIntensity, seconds: Double)] = []

        func secondsOf(_ s: WorkoutStep) -> Double {
            switch s.duration {
            case .time(let sec): return Double(sec)
            case .distance(let m): return Double(m) * 0.28      // environ 4:40 au km
            case .open: return 300
            }
        }

        for item in items {
            switch item {
            case .step(let s):
                out.append((s.intensity, secondsOf(s)))
            case .repeatBlock(let count, let steps):
                for _ in 0..<count {
                    for s in steps { out.append((s.intensity, secondsOf(s))) }
                }
            }
        }
        return out
    }
}

extension PlanIssue {
    var message: String {
        switch self {
        case .consecutiveHardSessions: return "deux séances dures d'affilée"
        case .legsNearKeySession: return "muscu jambes à moins de 48 h d'une séance clé"
        }
    }
}
