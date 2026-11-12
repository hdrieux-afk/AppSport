// TrainingLibrary.swift
// App Sport : bibliothèque de séances (course, vélo, muscu) et règles d'ajustement.
// Allures en m/s, FC en bpm. L'encodage FIT est une couche séparée, alimentée par EnduranceWorkout.
// Note : fichier non compilé à ce stade, à passer dans Xcode.

import Foundation

// MARK: - Fondations

enum Sport: String, Codable { case run, bike, strength }
enum SessionRole: String, Codable { case key, support }
enum Venue: String, Codable { case gym, home }

/// Décalage d'intensité proposé à l'utilisateur : Facile, Prévu, Intense.
enum Level: Int, Codable, CaseIterable { case easy = -1, planned = 0, hard = 1 }

struct AthleteProfile: Codable {
    var vmaKmh: Double
    var maxHR: Int
    var hasBand: Bool   // élastique disponible à la maison

    enum CodingKeys: String, CodingKey { case vmaKmh, maxHR, hasBand }
}

struct Zones {
    let maxHR: Int
    let vmaKmh: Double

    func hr(_ lo: Double, _ hi: Double) -> StepTarget {
        .heartRate(minBpm: Int((Double(maxHR) * lo).rounded()),
                   maxBpm: Int((Double(maxHR) * hi).rounded()))
    }
    func pace(_ lo: Double, _ hi: Double) -> StepTarget {
        .pace(minMps: vmaKmh * lo / 3.6, maxMps: vmaKmh * hi / 3.6)
    }
}

// MARK: - Modèle endurance (course, vélo) : mappable vers FIT workout / workout_step

enum StepIntensity { case warmup, active, recovery, rest, cooldown }
enum StepDuration { case time(seconds: Int), distance(meters: Int), open }
enum StepTarget {
    case pace(minMps: Double, maxMps: Double)
    case heartRate(minBpm: Int, maxBpm: Int)
    case open
}

struct WorkoutStep {
    var intensity: StepIntensity
    var duration: StepDuration
    var target: StepTarget
}

enum WorkoutItem {
    case step(WorkoutStep)
    case repeatBlock(count: Int, steps: [WorkoutStep])
}

struct EnduranceWorkout {
    var name: String
    var sport: Sport            // .run ou .bike
    var items: [WorkoutItem]
    var estimatedMinutes: Int
    var notes: String? = nil
}

private func item(_ i: StepIntensity, _ d: StepDuration, _ t: StepTarget) -> WorkoutItem {
    .step(WorkoutStep(intensity: i, duration: d, target: t))
}
private func ws(_ i: StepIntensity, _ d: StepDuration, _ t: StepTarget) -> WorkoutStep {
    WorkoutStep(intensity: i, duration: d, target: t)
}

// MARK: - Course : EF, fractionné court, fractionné long, sortie longue

enum RunSessionType: String, Codable, CaseIterable {
    case easyRun, shortIntervals, longIntervals, longRun

    var role: SessionRole { self == .easyRun ? .support : .key }

    var title: String {
        switch self {
        case .easyRun: return "Endurance fondamentale"
        case .shortIntervals: return "Fractionné court"
        case .longIntervals: return "Fractionné long"
        case .longRun: return "Sortie longue"
        }
    }

    var durationRange: ClosedRange<Int> {
        switch self {
        case .easyRun: return 20...75
        case .shortIntervals: return 35...45
        case .longIntervals: return 45...70
        case .longRun: return 40...180
        }
    }
}

enum RunVariant: String, Codable {
    case thirtyThirty, fortyFiveFortyFive, m200          // fractionné court
    case threeBy8, fourBy6, fiveBy1000, racePace         // fractionné long (racePace : allure objectif)
}

enum RunLibrary {

    static func build(_ type: RunSessionType, variant: RunVariant? = nil,
                      durationMin: Int, level: Level, zones z: Zones,
                      racePaceMps: Double? = nil) -> EnduranceWorkout {
        let d = min(max(durationMin, type.durationRange.lowerBound), type.durationRange.upperBound)
        switch type {
        case .easyRun: return easy(d, level, z)
        case .shortIntervals: return shortIntervals(variant ?? .thirtyThirty, d, level, z)
        case .longIntervals: return longIntervals(variant ?? .threeBy8, d, level, z, racePaceMps: racePaceMps)
        case .longRun: return longRun(d, level, z)
        }
    }

    // Bandes d'intensité selon le niveau choisi

    private static func enduranceBand(_ l: Level) -> (Double, Double) {
        switch l {
        case .easy: return (0.60, 0.70)
        case .planned: return (0.65, 0.75)
        case .hard: return (0.70, 0.80)
        }
    }
    private static func vmaBand(_ l: Level) -> (Double, Double) {
        switch l {
        case .easy: return (0.92, 1.00)
        case .planned: return (0.95, 1.05)
        case .hard: return (1.00, 1.10)
        }
    }
    private static func thresholdBand(_ l: Level) -> (Double, Double) {
        switch l {
        case .easy: return (0.78, 0.86)
        case .planned: return (0.80, 0.88)
        case .hard: return (0.83, 0.92)
        }
    }

    // Endurance fondamentale : 5 min libres, corps en FC, 5 min libres

    private static func easy(_ d: Int, _ l: Level, _ z: Zones) -> EnduranceWorkout {
        let (lo, hi) = enduranceBand(l)
        return EnduranceWorkout(
            name: "Endurance \(d)", sport: .run,
            items: [
                item(.warmup, .time(seconds: 300), .open),
                item(.active, .time(seconds: (d - 10) * 60), z.hr(lo, hi)),
                item(.cooldown, .time(seconds: 300), .open)
            ],
            estimatedMinutes: d, notes: "Allure conversationnelle")
    }

    // Fractionné court : échauffement 15 min, répétitions à allure VMA, retour au calme 10 min

    private static func shortIntervals(_ v: RunVariant, _ d: Int, _ l: Level, _ z: Zones) -> EnduranceWorkout {
        let (lo, hi) = vmaBand(l)
        let effort: StepDuration
        let recovery: StepDuration
        let cycleSec: Int
        let label: String
        switch v {
        case .fortyFiveFortyFive:
            effort = .time(seconds: 45); recovery = .time(seconds: 45); cycleSec = 90; label = "45/45"
        case .m200:
            effort = .distance(meters: 200); recovery = .time(seconds: 60); cycleSec = 110; label = "200 m"
        default:
            effort = .time(seconds: 30); recovery = .time(seconds: 30); cycleSec = 60; label = "30/30"
        }
        let reps = min(max(((d - 25) * 60) / cycleSec, 8), 20)
        let (elo, ehi) = enduranceBand(.planned)
        return EnduranceWorkout(
            name: "\(reps)x\(label)", sport: .run,
            items: [
                item(.warmup, .time(seconds: 900), z.hr(elo, ehi)),
                .repeatBlock(count: reps, steps: [
                    ws(.active, effort, z.pace(lo, hi)),
                    ws(.recovery, recovery, .open)
                ]),
                item(.cooldown, .time(seconds: 600), z.hr(elo, ehi))
            ],
            estimatedMinutes: 25 + reps * cycleSec / 60,
            notes: "Récupération en trot lent")
    }

    // Fractionné long : répétitions au seuil, 2 min de récupération (1 min 30 sur 1000 m)

    private static func longIntervals(_ v: RunVariant, _ d: Int, _ l: Level, _ z: Zones,
                                      racePaceMps: Double?) -> EnduranceWorkout {
        let (lo, hi) = thresholdBand(l)
        let spec: (effort: StepDuration, recSec: Int, cycleSec: Int, label: String)
        var target: StepTarget? = nil
        switch v {
        case .fourBy6: spec = (.time(seconds: 360), 120, 480, "6 min")
        case .fiveBy1000: spec = (.distance(meters: 1000), 90, 375, "1000 m")
        case .racePace where racePaceMps != nil:
            // Répétitions de 2 km à l'allure objectif, fourchette de ±1,5 % autour de l'allure.
            let mps = racePaceMps ?? 3.5
            spec = (.distance(meters: 2000), 120, Int(2000 / mps) + 120, "2 km")
            target = .pace(minMps: mps * 0.985, maxMps: mps * 1.015)
        default: spec = (.time(seconds: 480), 120, 600, "8 min")
        }
        let reps = min(max(Int((Double((d - 25) * 60) / Double(spec.cycleSec)).rounded()), 2), 6)
        let (elo, ehi) = enduranceBand(.planned)
        return EnduranceWorkout(
            name: "\(reps)x\(spec.label)", sport: .run,
            items: [
                item(.warmup, .time(seconds: 900), z.hr(elo, ehi)),
                .repeatBlock(count: reps, steps: [
                    ws(.active, spec.effort, target ?? z.pace(lo, hi)),
                    ws(.recovery, .time(seconds: spec.recSec), .open)
                ]),
                item(.cooldown, .time(seconds: 600), z.hr(elo, ehi))
            ],
            estimatedMinutes: 25 + reps * spec.cycleSec / 60,
            notes: "Allure seuil, régulière")
    }

    // Sortie longue : endurance, avec un finish progressif (10 min, 15 en Intense, aucun en Facile)

    private static func longRun(_ d: Int, _ l: Level, _ z: Zones) -> EnduranceWorkout {
        let (lo, hi) = enduranceBand(l)
        let finish = (l == .easy) ? 0 : (l == .hard ? 15 : 10)
        var items: [WorkoutItem] = [
            item(.warmup, .time(seconds: 300), .open),
            item(.active, .time(seconds: (d - 10 - finish) * 60), z.hr(lo, hi))
        ]
        if finish > 0 {
            items.append(item(.active, .time(seconds: finish * 60), z.hr(0.75, 0.82)))
        }
        items.append(item(.cooldown, .time(seconds: 300), .open))
        return EnduranceWorkout(
            name: "Longue \(d)", sport: .run, items: items,
            estimatedMinutes: d,
            notes: finish > 0 ? "Finish progressif sur les \(finish) dernières minutes" : nil)
    }
}

// MARK: - Vélo : une seule sortie générique (durée + intensité)

enum BikeLibrary {
    static let durationRange = 30...180

    /// Bandes de FC à calibrer : la FC à vélo est souvent un peu plus basse qu'en course.
    static func build(durationMin: Int, level: Level, zones z: Zones) -> EnduranceWorkout {
        let d = min(max(durationMin, durationRange.lowerBound), durationRange.upperBound)
        let band: (Double, Double)
        switch level {
        case .easy: band = (0.60, 0.70)
        case .planned: band = (0.65, 0.75)
        case .hard: band = (0.72, 0.82)
        }
        return EnduranceWorkout(
            name: "Vélo \(d)", sport: .bike,
            items: [
                item(.warmup, .time(seconds: 600), .open),
                item(.active, .time(seconds: (d - 15) * 60), z.hr(band.0, band.1)),
                item(.cooldown, .time(seconds: 300), .open)
            ],
            estimatedMinutes: d, notes: nil)
    }
}

// MARK: - Muscu : description uniquement, aucun fichier FIT

enum StrengthFocus: String, Codable, CaseIterable { case fullBody, legs, push, pull }
enum Equipment: String, Codable { case none, band, gym }

enum RepScheme: Codable {
    case reps(Int)
    case repsPerSide(Int)
    case toFailureMinus(Int)    // répétitions max moins N
    case seconds(Int)
}

struct Exercise {
    let id: String
    let name: String
    let equipment: Equipment
    var fallbackID: String? = nil     // repli sans élastique
    var safetyNote: String? = nil
}

struct StrengthItem {
    var exercise: Exercise
    var sets: Int
    var scheme: RepScheme
}

struct StrengthWorkout {
    var focus: StrengthFocus
    var venue: Venue
    var items: [StrengthItem]
    var estimatedMinutes: Int
    var warmup: String
}

enum StrengthLibrary {

    private static let doorNote = "Ancrage sur une porte : porte fermée, nœud de butée solide (consigne à valider)."

    private static func e(_ id: String, _ name: String, _ eq: Equipment,
                          fallback: String? = nil, note: String? = nil) -> Exercise {
        Exercise(id: id, name: name, equipment: eq, fallbackID: fallback, safetyNote: note)
    }

    private static let all: [Exercise] = [
        // Maison, poids du corps
        e("squat", "Squats", .none),
        e("pushup", "Pompes", .none),
        e("pike", "Pompes pike", .none),
        e("lunge_back", "Fentes arrière", .none),
        e("glute_bridge_1", "Pont fessier sur une jambe", .none),
        e("calf_1", "Mollets sur une jambe", .none),
        e("plank", "Planche", .none),
        e("superman", "Superman", .none),
        e("inverted_row", "Rowing inversé sous une table", .none),
        e("good_morning_bw", "Good morning au poids du corps", .none),
        // Maison, élastique (repli sans matériel)
        e("band_row", "Rowing assis à l'élastique", .band, fallback: "inverted_row"),
        e("band_pulldown", "Tirage vertical, élastique ancré en haut d'une porte", .band,
          fallback: "inverted_row", note: doorNote),
        e("band_face_pull", "Face pull à l'élastique", .band, fallback: "superman", note: doorNote),
        e("band_curl", "Curl biceps debout sur l'élastique", .band, fallback: "superman"),
        e("band_ohp", "Développé épaules debout sur l'élastique", .band, fallback: "pike"),
        e("band_chest_press", "Développé pectoraux, élastique dans le dos", .band, fallback: "pushup"),
        e("band_triceps", "Extensions triceps à l'élastique", .band, fallback: "pushup"),
        e("band_squat", "Squats, élastique sous les pieds", .band, fallback: "squat"),
        e("band_good_morning", "Good morning à l'élastique", .band, fallback: "good_morning_bw"),
        // Salle
        e("gym_squat", "Squat à la barre ou presse", .gym),
        e("gym_rdl", "Soulevé de terre roumain", .gym),
        e("gym_lunge", "Fentes aux haltères", .gym),
        e("gym_leg_curl", "Leg curl", .gym),
        e("gym_calf", "Mollets à la machine", .gym),
        e("gym_bench", "Développé couché", .gym),
        e("gym_incline", "Développé incliné", .gym),
        e("gym_ohp", "Développé épaules aux haltères", .gym),
        e("gym_lateral", "Élévations latérales", .gym),
        e("gym_triceps", "Extensions triceps à la poulie", .gym),
        e("gym_pulldown", "Tractions ou tirage vertical", .gym),
        e("gym_row", "Rowing barre ou haltère", .gym),
        e("gym_cable_row", "Tirage poulie basse", .gym),
        e("gym_face_pull", "Face pull à la poulie", .gym),
        e("gym_curl", "Curl biceps", .gym)
    ]

    static let catalog: [String: Exercise] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    struct Slot {
        let id: String
        let sets: Int
        let scheme: RepScheme
    }
    private static func s(_ id: String, _ sets: Int, _ scheme: RepScheme) -> Slot {
        Slot(id: id, sets: sets, scheme: scheme)
    }

    /// 6 créneaux par modèle, par ordre de priorité. La durée choisie en retient 3 à 6.
    static let templates: [String: [Slot]] = [
        "fullBody.gym": [s("gym_squat", 3, .reps(10)), s("gym_bench", 3, .reps(10)),
                         s("gym_row", 3, .reps(10)), s("gym_rdl", 3, .reps(10)),
                         s("plank", 3, .seconds(40)), s("gym_ohp", 2, .reps(10))],
        "fullBody.home": [s("squat", 3, .reps(15)), s("pushup", 3, .toFailureMinus(2)),
                          s("band_row", 3, .reps(12)), s("band_good_morning", 3, .reps(12)),
                          s("plank", 3, .seconds(40)), s("lunge_back", 2, .repsPerSide(10))],
        "legs.gym": [s("gym_squat", 4, .reps(8)), s("gym_rdl", 3, .reps(10)),
                     s("gym_lunge", 3, .repsPerSide(10)), s("gym_leg_curl", 3, .reps(12)),
                     s("gym_calf", 3, .reps(15)), s("plank", 3, .seconds(40))],
        "legs.home": [s("lunge_back", 3, .repsPerSide(10)), s("band_squat", 4, .reps(12)),
                      s("glute_bridge_1", 3, .repsPerSide(12)), s("band_good_morning", 3, .reps(12)),
                      s("calf_1", 3, .repsPerSide(15)), s("plank", 3, .seconds(40))],
        "push.gym": [s("gym_bench", 4, .reps(8)), s("gym_ohp", 3, .reps(10)),
                     s("gym_incline", 3, .reps(10)), s("gym_lateral", 3, .reps(12)),
                     s("gym_triceps", 3, .reps(12)), s("plank", 3, .seconds(40))],
        "push.home": [s("pushup", 4, .toFailureMinus(2)), s("pike", 3, .reps(8)),
                      s("band_ohp", 3, .reps(10)), s("band_chest_press", 3, .reps(12)),
                      s("band_triceps", 3, .reps(12)), s("plank", 3, .seconds(40))],
        "pull.gym": [s("gym_pulldown", 4, .reps(8)), s("gym_row", 4, .reps(8)),
                     s("gym_cable_row", 3, .reps(10)), s("gym_face_pull", 3, .reps(12)),
                     s("gym_curl", 3, .reps(10)), s("plank", 3, .seconds(40))],
        "pull.home": [s("band_row", 4, .reps(12)), s("band_pulldown", 4, .reps(10)),
                      s("band_face_pull", 3, .reps(15)), s("superman", 3, .reps(12)),
                      s("band_curl", 3, .reps(12)), s("plank", 3, .seconds(40))]
    ]

    static func build(_ focus: StrengthFocus, venue: Venue, durationMin: Int,
                      level: Level, profile: AthleteProfile) -> StrengthWorkout {
        let slots = templates["\(focus.rawValue).\(venue.rawValue)"] ?? []
        let count = min(max((durationMin - 5) / 8, 3), slots.count)

        let items: [StrengthItem] = slots.prefix(count).compactMap { slot -> StrengthItem? in
            guard var ex = catalog[slot.id] else { return nil }
            // Sans élastique à la maison : on bascule sur l'exercice de repli.
            if venue == .home, ex.equipment == .band, !profile.hasBand,
               let fb = ex.fallbackID, let alt = catalog[fb] {
                ex = alt
            }
            return StrengthItem(exercise: ex, sets: max(2, slot.sets + level.rawValue), scheme: slot.scheme)
        }
        let totalSets = items.reduce(0) { $0 + $1.sets }
        return StrengthWorkout(
            focus: focus, venue: venue, items: items,
            estimatedMinutes: 5 + Int((Double(totalSets) * 2.5).rounded()),
            warmup: "5 min : mobilité, puis une série légère du premier exercice")
    }
}

// MARK: - Séance du plan et actions utilisateur (Modifier, Changer de sport, Annuler)

enum SessionKind: Codable, Equatable {
    case run(RunSessionType)
    case bike
    case strength(StrengthFocus, Venue)

    var sport: Sport {
        switch self {
        case .run: return .run
        case .bike: return .bike
        case .strength: return .strength
        }
    }

    /// Seules les séances clés de course sont « clé » : le reste est du soutien.
    var role: SessionRole {
        if case .run(let t) = self { return t.role }
        return .support
    }

    /// Effort perçu moyen sur la séance (1 à 10), base de l'équivalence de charge.
    var baseRPE: Double {
        switch self {
        case .run(let t):
            switch t {
            case .easyRun: return 4
            case .longRun: return 5
            case .shortIntervals, .longIntervals: return 6
            }
        case .bike: return 4
        case .strength: return 5
        }
    }

    var durationRange: ClosedRange<Int> {
        switch self {
        case .run(let t): return t.durationRange
        case .bike: return BikeLibrary.durationRange
        case .strength: return 30...60
        }
    }
}

enum SessionStatus: String, Codable { case planned, modified, cancelled, done }

struct TrainingSession: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var kind: SessionKind
    var variant: RunVariant? = nil
    var durationMin: Int
    var level: Level = .planned
    var status: SessionStatus = .planned
    var isLocked = false        // modifiée à la main : jamais écrasée par une régénération du plan
    var fitRevision = 0         // incrémentée à chaque changement qui touche le fichier
    var isDone = false          // séance marquée comme faite par l'utilisateur
    var intervalsEventID: Int? = nil   // événement correspondant dans intervals.icu, une fois la séance envoyée

    enum CodingKeys: String, CodingKey {
        case id, date, kind, variant, durationMin, level, status, isLocked, fitRevision, isDone, intervalsEventID
    }

    var isExportable: Bool { kind.sport != .strength && status != .cancelled }

    private mutating func bumpRevision() {
        if isExportable { fitRevision += 1 }
    }

    /// Modifier : durée et intensité. Étapes et cibles sont recalculées au rendu de la séance.
    mutating func modify(durationMin newDuration: Int, level newLevel: Level) {
        durationMin = min(max(newDuration, kind.durationRange.lowerBound), kind.durationRange.upperBound)
        level = newLevel
        status = .modified
        isLocked = true
        bumpRevision()
    }

    /// Changer de sport : durée recalculée à charge équivalente (durée × effort perçu).
    mutating func changeSport(to newKind: SessionKind, variant newVariant: RunVariant? = nil) {
        let load = Double(durationMin) * (kind.baseRPE + Double(level.rawValue))
        let raw = load / newKind.baseRPE
        let rounded = Int((raw / 5).rounded()) * 5
        kind = newKind
        variant = newVariant
        durationMin = min(max(rounded, newKind.durationRange.lowerBound), newKind.durationRange.upperBound)
        level = .planned
        status = .modified
        isLocked = true
        bumpRevision()      // course ou vélo : nouveau fichier. Muscu : aucun fichier (isExportable = false).
    }

    /// Annuler : la séance devient du repos, son fichier n'est plus exportable.
    mutating func cancel() {
        status = .cancelled
        isLocked = true
    }

    /// Déplacer : seule la date change, la séance et son fichier restent identiques.
    mutating func move(to newDate: Date) {
        date = newDate
        status = .modified
        isLocked = true
    }

    /// Marquer comme faite (ou remettre à faire). Une séance faite n'est jamais écrasée par une régénération.
    mutating func setDone(_ done: Bool) {
        isDone = done
    }

    /// Nom interne court (le nom du workout FIT est limité en longueur, à vérifier dans le SDK)
    /// et nom de fichier complet avec date et version.
    func fitNames(for workout: EnduranceWorkout) -> (watchName: String, fileName: String) {
        let rev = "v\(fitRevision + 1)"
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE dd-MM"
        return (String("\(workout.name) \(rev)".prefix(15)),
                "\(f.string(from: date)) \(workout.name) \(rev).fit")
    }
}

// MARK: - Exemple d'usage
//
// let profile = AthleteProfile(vmaKmh: 15, maxHR: 190, hasBand: true)
// let zones = Zones(maxHR: profile.maxHR, vmaKmh: profile.vmaKmh)
//
// var session = TrainingSession(date: Date(), kind: .run(.longIntervals), durationMin: 55)
// let w1 = RunLibrary.build(.longIntervals, durationMin: session.durationMin, level: session.level, zones: zones)
//
// session.modify(durationMin: 50, level: .easy)          // Modifier : fichier v1
// session.changeSport(to: .bike)                         // Changer de sport : 55 min de fractionné long deviennent 85 min de vélo
// session.cancel()                                       // Annuler
//
// let gym = StrengthLibrary.build(.pull, venue: .home, durationMin: 45, level: .planned, profile: profile)

// MARK: - Lecture tolérante des sauvegardes
// Une sauvegarde faite par une ancienne version de l'app (sans les champs ajoutés depuis) reste lisible :
// les champs absents reçoivent leur valeur par défaut, au lieu de faire disparaître le plan.

extension TrainingSession {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try c.decode(Date.self, forKey: .date)
        kind = try c.decode(SessionKind.self, forKey: .kind)
        variant = try c.decodeIfPresent(RunVariant.self, forKey: .variant)
        durationMin = try c.decode(Int.self, forKey: .durationMin)
        level = try c.decodeIfPresent(Level.self, forKey: .level) ?? .planned
        status = try c.decodeIfPresent(SessionStatus.self, forKey: .status) ?? .planned
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        fitRevision = try c.decodeIfPresent(Int.self, forKey: .fitRevision) ?? 0
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        intervalsEventID = try c.decodeIfPresent(Int.self, forKey: .intervalsEventID)
    }
}

extension AthleteProfile {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vmaKmh = try c.decode(Double.self, forKey: .vmaKmh)
        maxHR = try c.decode(Int.self, forKey: .maxHR)
        hasBand = try c.decodeIfPresent(Bool.self, forKey: .hasBand) ?? false
    }
}
