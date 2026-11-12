// PlanGenerator.swift
// App Sport : contraintes utilisateur, objectif course (avec temps visé), phases,
// composition de la semaine et placement des séances sur les jours.
// Dépend de TrainingLibrary.swift. Fichier non compilé à ce stade, à passer dans Xcode.

import Foundation

// MARK: - Profil : VMA saisie à l'onboarding

extension AthleteProfile {
    /// Plage de validation de la VMA saisie (km/h).
    var isVMAValid: Bool { (8.0...25.0).contains(vmaKmh) }
}

// MARK: - Objectif course

enum RaceDistance: String, Codable, CaseIterable {
    case fiveK, tenK, half, marathon

    var meters: Double {
        switch self {
        case .fiveK: return 5_000
        case .tenK: return 10_000
        case .half: return 21_097.5
        case .marathon: return 42_195
        }
    }

    /// Part de VMA habituellement tenue sur la distance. Valeurs indicatives, à valider avec un coach.
    var vmaFractionRange: ClosedRange<Double> {
        switch self {
        case .fiveK: return 0.92...0.96
        case .tenK: return 0.88...0.92
        case .half: return 0.82...0.86
        case .marathon: return 0.75...0.80
        }
    }

    var minWeeks: Int {
        switch self {
        case .fiveK: return 6
        case .tenK: return 8
        case .half: return 10
        case .marathon: return 12
        }
    }

    var minRunsPerWeek: Int {
        switch self {
        case .fiveK, .tenK: return 2
        case .half, .marathon: return 3
        }
    }

    var taperWeeks: Int { (self == .half || self == .marathon) ? 2 : 1 }

    /// Durée de sortie longue visée au pic du plan (minutes). Valeurs indicatives, à valider avec un coach.
    var peakLongRunMinutes: Int {
        switch self {
        case .fiveK: return 75
        case .tenK: return 90
        case .half: return 120
        case .marathon: return 150
        }
    }
}

struct RaceGoal: Codable {
    var distance: RaceDistance
    var date: Date
    var targetSeconds: Double? = nil      // temps visé, optionnel

    var targetPaceMps: Double? { targetSeconds.map { distance.meters / $0 } }
}

enum Feasibility: String, Codable { case cautious, realistic, ambitious, veryAmbitious }

/// Prudent sous la plage habituelle, réaliste dedans, ambitieux jusqu'à 3 points au-dessus, très ambitieux au-delà.
func assessFeasibility(_ goal: RaceGoal, vmaKmh: Double) -> (level: Feasibility, vmaFraction: Double)? {
    guard let pace = goal.targetPaceMps, vmaKmh > 0 else { return nil }
    let fraction = pace * 3.6 / vmaKmh
    let range = goal.distance.vmaFractionRange
    let level: Feasibility
    if fraction < range.lowerBound {
        level = .cautious
    } else if fraction <= range.upperBound {
        level = .realistic
    } else if fraction <= range.upperBound + 0.03 {
        level = .ambitious
    } else {
        level = .veryAmbitious
    }
    return (level, fraction)
}

// MARK: - Contraintes saisies par l'utilisateur

struct PlanConstraints: Codable {
    var runs: Int
    var bikes: Int
    var strengths: Int
    var strengthVenue: Venue = .home
    var unavailableWeekdays: Set<Int> = []      // 0 = lundi ... 6 = dimanche
    var goal: RaceGoal? = nil
    var currentLongRunMinutes: Int = 60         // sortie de course la plus longue de ces 4 dernières semaines
    var layoutSeed: Int = 0                     // fait varier la disposition proposée (bouton "Régénérer")

    var total: Int { runs + bikes + strengths }
    var availableDays: [Int] { (0..<7).filter { !unavailableWeekdays.contains($0) } }
    var isValid: Bool { (2...7).contains(total) && total <= availableDays.count }

    /// Avertissements non bloquants : l'utilisateur garde le dernier mot.
    func warnings(now: Date = Date(), calendar: Calendar = .current) -> [String] {
        var out: [String] = []
        guard let goal = goal else { return out }
        let weeks = calendar.dateComponents([.weekOfYear], from: now, to: goal.date).weekOfYear ?? 0
        if weeks < goal.distance.minWeeks {
            out.append("Délai court pour cette distance : \(weeks) semaines, \(goal.distance.minWeeks) recommandées.")
        }
        if runs < goal.distance.minRunsPerWeek {
            out.append("Moins de \(goal.distance.minRunsPerWeek) séances de course par semaine pour cette distance.")
        }
        let start = PlanGenerator.nextMonday(from: now, calendar: calendar)
        if PlanGenerator.timeline(for: self, start: start, calendar: calendar).peakCapped {
            out.append("Votre volume actuel ne permet pas d'atteindre la sortie longue visée sans dépasser 10 % de hausse par semaine : le plan montera aussi haut que possible.")
        }
        return out
    }
}

// MARK: - Phases et volume

enum PlanPhase: String, Codable { case base, development, specific, taper }

struct PlanTimeline {
    let totalWeeks: Int
    let taperWeeks: Int
    let hasGoal: Bool
    /// Durée visée de la sortie longue chaque semaine : elle pilote tout le volume de la semaine.
    let longRunMinutes: [Int]
    let deloadWeeks: Set<Int>
    /// Vrai si la hausse limitée à 10 % par semaine ne permet pas d'atteindre le pic visé.
    let peakCapped: Bool

    /// Sortie longue de référence sur laquelle sont calées les durées de base des séances.
    static let referenceLongRun = 80.0
    static let maxWeeklyGrowth = 1.10

    /// Construit la progression : on part du volume actuel et on monte vers le pic de la distance visée,
    /// avec au plus 10 % de hausse d'une semaine de montée à l'autre.
    static func make(totalWeeks: Int, taperWeeks: Int, hasGoal: Bool,
                     startLongRun: Int, peakLongRun: Int) -> PlanTimeline {
        let start = Double(min(max(startLongRun, 30), 180))
        let peak = max(Double(min(max(peakLongRun, 30), 180)), start)
        let body = hasGoal ? max(totalWeeks - taperWeeks, 0) : totalWeeks

        // Une semaine de décharge toutes les 4 semaines, jamais dans les 2 dernières semaines avant l'affûtage.
        var deloads = Set<Int>()
        for w in 0..<body where (w + 1) % 4 == 0 {
            if hasGoal && w >= body - 2 { continue }
            deloads.insert(w)
        }

        let buildCount = body - deloads.count
        var values = [Double](repeating: start, count: max(totalWeeks, 0))
        var previous = start
        var capped = false
        var k = 0
        for w in 0..<body {
            if deloads.contains(w) {
                values[w] = previous * 0.75
            } else {
                let target = start + (peak - start) * Double(k) / Double(max(buildCount - 1, 1))
                let value = (k == 0) ? start : min(target, previous * maxWeeklyGrowth)
                values[w] = value
                previous = value
                if k == buildCount - 1 && value < peak - 0.5 { capped = true }
                k += 1
            }
        }

        // Affûtage : volume réduit à partir du dernier niveau atteint.
        if hasGoal && taperWeeks > 0 {
            for t in 0..<taperWeeks where body + t < totalWeeks {
                values[body + t] = previous * (t == taperWeeks - 1 ? 0.55 : 0.75)
            }
        }

        return PlanTimeline(totalWeeks: totalWeeks, taperWeeks: taperWeeks, hasGoal: hasGoal,
                            longRunMinutes: values.map { Int($0.rounded()) },
                            deloadWeeks: deloads, peakCapped: capped)
    }

    func phase(of week: Int) -> PlanPhase {
        // Sans objectif : blocs de 4 semaines, 2 semaines de base puis 2 de développement.
        guard hasGoal else { return week % 4 < 2 ? .base : .development }
        if week >= totalWeeks - taperWeeks { return .taper }
        let body = totalWeeks - taperWeeks
        let base = max(1, Int((Double(body) * 0.3).rounded()))
        let specific = max(1, Int((Double(body) * 0.3).rounded()))
        if week < base { return .base }
        if week >= body - specific { return .specific }
        return .development
    }

    /// Facteur appliqué aux durées de base : sortie longue de la semaine divisée par la référence.
    func volumeFactor(of week: Int) -> Double {
        guard longRunMinutes.indices.contains(week) else { return 1.0 }
        return Double(longRunMinutes[week]) / PlanTimeline.referenceLongRun
    }
}

// MARK: - Créneaux de séance

struct SessionSlot {
    var kind: SessionKind
    var variant: RunVariant? = nil
    var baseDuration: Int

    /// Séance dure : fractionné ou sortie longue.
    var isHard: Bool {
        if case .run(let t) = kind { return t.role == .key }
        return false
    }
    /// Muscu qui sollicite fortement les jambes.
    var isStrengthLegHeavy: Bool {
        if case .strength(let f, _) = kind { return f == .legs || f == .fullBody }
        return false
    }
    var isLight: Bool { !isHard && !isStrengthLegHeavy }
}

// MARK: - Composition de la semaine

enum PlanComposer {

    private static let shortVariants: [RunVariant] = [.thirtyThirty, .fortyFiveFortyFive, .m200]
    private static let longVariants: [RunVariant] = [.threeBy8, .fourBy6, .fiveBy1000]

    private static func baseDuration(_ t: RunSessionType) -> Int {
        switch t {
        case .easyRun: return 45
        case .shortIntervals: return 40
        case .longIntervals: return 55
        case .longRun: return 80
        }
    }

    /// Créneaux par ordre de priorité : si la place manque, les derniers sautent.
    static func slots(for c: PlanConstraints, phase: PlanPhase, week: Int, goal: RaceGoal?,
                      seed: Int = 0) -> [SessionSlot] {
        var out: [SessionSlot] = []

        // Course : 1 fractionné, 1 sortie longue, puis endurance. 2e fractionné en développement dès 4 séances.
        let interval: RunSessionType = (phase == .base || phase == .taper) ? .shortIntervals : .longIntervals
        let secondInterval: RunSessionType = (interval == .shortIntervals) ? .longIntervals : .shortIntervals
        var run: [RunSessionType] = []
        switch c.runs {
        case 0: break
        case 1: run = [.longRun]
        case 2: run = [interval, .longRun]
        case 3: run = [interval, .longRun, .easyRun]
        default:
            run = [interval, .longRun, phase == .development ? secondInterval : .easyRun]
            while run.count < c.runs { run.append(.easyRun) }
        }
        for t in run {
            var variant: RunVariant? = nil
            if t == .shortIntervals { variant = shortVariants[(week + seed) % 3] }
            if t == .longIntervals {
                let useRacePace = (phase == .specific && goal?.targetSeconds != nil)
                variant = useRacePace ? RunVariant.racePace : longVariants[(week + seed) % 3]
            }
            out.append(SessionSlot(kind: .run(t), variant: variant, baseDuration: baseDuration(t)))
        }

        // Vélo : une sortie générique.
        for _ in 0..<c.bikes {
            out.append(SessionSlot(kind: .bike, baseDuration: 60))
        }

        // Muscu : rotation des focus.
        let focuses: [StrengthFocus]
        switch c.strengths {
        case 0: focuses = []
        case 1: focuses = [.fullBody]
        case 2: focuses = [.legs, ((week + seed) % 2 == 0) ? StrengthFocus.push : StrengthFocus.pull]
        case 3: focuses = [.legs, .push, .pull]
        default: focuses = [.legs, .push, .pull] + Array(repeating: StrengthFocus.fullBody, count: c.strengths - 3)
        }
        for f in focuses {
            out.append(SessionSlot(kind: .strength(f, c.strengthVenue), baseDuration: 45))
        }
        return out
    }

    /// Durée de la semaine : durée de base × facteur de volume, arrondie à 5 min et bornée par le type de séance.
    static func duration(_ slot: SessionSlot, factor: Double) -> Int {
        let rounded = Int((Double(slot.baseDuration) * factor / 5).rounded()) * 5
        let r = slot.kind.durationRange
        return min(max(rounded, r.lowerBound), r.upperBound)
    }
}

// MARK: - Placement sur les jours

typealias PlacedSlot = (day: Int, slot: SessionSlot)

enum PlanPlacer {

    /// Plus la note est basse, meilleur est le placement.
    /// Jours : 0 = lundi ... 6 = dimanche, adjacence cyclique (la semaine se répète).
    static func penalty(_ placed: [PlacedSlot]) -> Int {
        var p = 0
        for i in 0..<placed.count {
            let a = placed[i]
            if case .run(.longRun) = a.slot.kind, a.day < 5 { p += 10 }     // sortie longue de préférence le week-end
            for j in (i + 1)..<placed.count {
                let b = placed[j]
                let gap = abs(a.day - b.day)
                let d = min(gap, 7 - gap)
                if d == 1 { p += 2 }                                         // espacer les séances
                if d == 1, a.slot.isHard, b.slot.isHard { p += 1000 }        // jamais deux séances dures d'affilée (contrainte absolue)
                let legsNearHard = (a.slot.isStrengthLegHeavy && b.slot.isHard)
                    || (b.slot.isStrengthLegHeavy && a.slot.isHard)
                if d <= 1, legsNearHard { p += 60 }                          // muscu jambes à 48 h d'une séance clé
                if d == 1, a.slot.isStrengthLegHeavy, b.slot.isStrengthLegHeavy { p += 40 }
            }
        }
        // À 7 séances, au moins une séance légère.
        if placed.count == 7, !placed.contains(where: { $0.slot.isLight }) { p += 200 }
        return p
    }

    /// Teste tous les placements possibles (5 040 au maximum pour 7 jours), les classe par note, puis en choisit un.
    /// seed = 0 donne le meilleur placement ; une graine plus grande donne une autre disposition presque aussi
    /// bonne (10 points d'écart au plus), ce qui alimente le bouton "Régénérer".
    static func place(_ slots: [SessionSlot], fixed: [PlacedSlot] = [], freeDays: [Int],
                      seed: Int = 0) -> [PlacedSlot] {
        guard !slots.isEmpty, slots.count <= freeDays.count else { return [] }
        var candidates: [(score: Int, placement: [PlacedSlot])] = []
        var bestSeen = Int.max
        var current: [PlacedSlot] = []
        var used = Set<Int>()

        func search(_ i: Int) {
            if i == slots.count {
                let score = penalty(fixed + current)
                if bestSeen == Int.max || score <= bestSeen + 10 {
                    candidates.append((score: score, placement: current))
                }
                if score < bestSeen { bestSeen = score }
                return
            }
            for day in freeDays where !used.contains(day) {
                used.insert(day)
                current.append((day: day, slot: slots[i]))
                search(i + 1)
                current.removeLast()
                used.remove(day)
            }
        }
        search(0)

        guard let best = candidates.map({ $0.score }).min() else { return [] }

        // Les placements qui ne diffèrent que par l'échange de deux séances identiques comptent pour un seul.
        var seen = Set<String>()
        var near: [(score: Int, key: String, placement: [PlacedSlot])] = []
        for c in candidates where c.score <= best + 10 {
            let key = c.placement
                .sorted { $0.day < $1.day }
                .map { "\($0.day):\($0.slot.kind)" }
                .joined(separator: "|")
            if seen.insert(key).inserted {
                near.append((score: c.score, key: key, placement: c.placement))
            }
        }
        near.sort { ($0.score, $0.key) < ($1.score, $1.key) }
        guard !near.isEmpty else { return [] }
        return near[((seed % near.count) + near.count) % near.count].placement
    }
}

// MARK: - Génération du plan

struct PlannedWeek: Codable, Identifiable {
    var index: Int
    var phase: PlanPhase
    var sessions: [TrainingSession]

    var id: Int { index }
}

enum PlanGenerator {

    /// Lundi de la semaine suivante (point de départ conseillé du plan).
    static func nextMonday(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: date, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) ?? date
    }

    static func timeline(for c: PlanConstraints, start: Date, calendar: Calendar = .current) -> PlanTimeline {
        let startLongRun = max(30, c.currentLongRunMinutes)
        guard let goal = c.goal else {
            return PlanTimeline.make(totalWeeks: 4, taperWeeks: 0, hasGoal: false, startLongRun: startLongRun,
                                     peakLongRun: Int((Double(startLongRun) * 1.2).rounded()))
        }
        let days = calendar.dateComponents([.day], from: start, to: goal.date).day ?? 0
        let weeks = min(max((days + 6) / 7, 1), 24)
        return PlanTimeline.make(totalWeeks: weeks, taperWeeks: goal.distance.taperWeeks, hasGoal: true,
                                 startLongRun: startLongRun, peakLongRun: goal.distance.peakLongRunMinutes)
    }

    static func generatePlan(constraints c: PlanConstraints, start: Date,
                             calendar: Calendar = .current) -> [PlannedWeek] {
        let tl = timeline(for: c, start: start, calendar: calendar)
        return (0..<tl.totalWeeks).map { w in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: w, to: start) ?? start
            return generateWeek(week: w, weekStart: weekStart, constraints: c, timeline: tl,
                                seed: c.layoutSeed, calendar: calendar)
        }
    }

    /// Les séances verrouillées gardent leur jour et consomment un créneau du même sport :
    /// une régénération ne refait que le reste de la semaine.
    static func generateWeek(week: Int, weekStart: Date, constraints c: PlanConstraints,
                             timeline tl: PlanTimeline, locked: [TrainingSession] = [],
                             seed: Int = 0, calendar: Calendar = .current) -> PlannedWeek {
        let phase = tl.phase(of: week)
        var slots = PlanComposer.slots(for: c, phase: phase, week: week, goal: c.goal, seed: seed)

        func dayIndex(of s: TrainingSession) -> Int {
            let d = calendar.dateComponents([.day], from: weekStart, to: s.date).day ?? 0
            return min(max(d, 0), 6)
        }

        for s in locked {
            if let idx = slots.firstIndex(where: { $0.kind.sport == s.kind.sport }) {
                slots.remove(at: idx)
            }
        }
        let lockedDays = Set(locked.map { dayIndex(of: $0) })
        let fixed: [PlacedSlot] = locked
            .filter { $0.status != .cancelled }
            .map { (day: dayIndex(of: $0),
                    slot: SessionSlot(kind: $0.kind, variant: $0.variant, baseDuration: $0.durationMin)) }
        let freeDays = c.availableDays.filter { !lockedDays.contains($0) }
        slots = Array(slots.prefix(freeDays.count))

        let factor = tl.volumeFactor(of: week)
        let created = PlanPlacer.place(slots, fixed: fixed, freeDays: freeDays, seed: seed).map { p -> TrainingSession in
            let date = calendar.date(byAdding: .day, value: p.day, to: weekStart) ?? weekStart
            return TrainingSession(date: date, kind: p.slot.kind, variant: p.slot.variant,
                                   durationMin: PlanComposer.duration(p.slot, factor: factor))
        }
        return PlannedWeek(index: week, phase: phase, sessions: (locked + created).sorted { $0.date < $1.date })
    }
}

// MARK: - Vérifications d'une semaine

enum PlanIssue: Equatable {
    case consecutiveHardSessions      // deux séances dures le même jour ou deux jours de suite
    case legsNearKeySession           // muscu jambes à moins de 48 h d'une séance clé
}

enum PlanChecks {
    /// Problèmes de placement dans une semaine, sans texte d'interface (le texte vit dans la couche présentation).
    static func issues(in sessions: [TrainingSession], weekStart: Date,
                       calendar: Calendar = .current) -> [PlanIssue] {
        let active = sessions.filter { $0.status != .cancelled }

        func day(_ s: TrainingSession) -> Int {
            let d = calendar.dateComponents([.day], from: weekStart, to: s.date).day ?? 0
            return min(max(d, 0), 6)
        }

        var found: [PlanIssue] = []
        for i in 0..<active.count {
            for j in (i + 1)..<active.count {
                guard abs(day(active[i]) - day(active[j])) <= 1 else { continue }
                let a = SessionSlot(kind: active[i].kind, baseDuration: active[i].durationMin)
                let b = SessionSlot(kind: active[j].kind, baseDuration: active[j].durationMin)
                if a.isHard && b.isHard && !found.contains(.consecutiveHardSessions) {
                    found.append(.consecutiveHardSessions)
                }
                let legsNearHard = (a.isStrengthLegHeavy && b.isHard) || (b.isStrengthLegHeavy && a.isHard)
                if legsNearHard && !found.contains(.legsNearKeySession) {
                    found.append(.legsNearKeySession)
                }
            }
        }
        return found
    }
}

// MARK: - Rendu d'une séance (étapes et cibles, ou description de muscu)

enum BuiltSession {
    case endurance(EnduranceWorkout)
    case strength(StrengthWorkout)
}

extension TrainingSession {
    func render(profile: AthleteProfile, goal: RaceGoal?) -> BuiltSession {
        let zones = Zones(maxHR: profile.maxHR, vmaKmh: profile.vmaKmh)
        switch kind {
        case .run(let t):
            return .endurance(RunLibrary.build(t, variant: variant, durationMin: durationMin,
                                               level: level, zones: zones,
                                               racePaceMps: goal?.targetPaceMps))
        case .bike:
            return .endurance(BikeLibrary.build(durationMin: durationMin, level: level, zones: zones))
        case .strength(let f, let v):
            return .strength(StrengthLibrary.build(f, venue: v, durationMin: durationMin,
                                                   level: level, profile: profile))
        }
    }
}

// MARK: - Exemple d'usage
//
// let profile = AthleteProfile(vmaKmh: 15, maxHR: 190, hasBand: true)
// let race = RaceGoal(distance: .tenK, date: someDate, targetSeconds: 45 * 60)
// let constraints = PlanConstraints(runs: 3, bikes: 1, strengths: 1, goal: race)
// let start = PlanGenerator.nextMonday(from: Date())
// let plan = PlanGenerator.generatePlan(constraints: constraints, start: start)
// let verdict = assessFeasibility(race, vmaKmh: profile.vmaKmh)   // (.realistic, 0.889)
// let built = plan[0].sessions[0].render(profile: profile, goal: race)
