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
        return out
    }
}

// MARK: - Phases et volume

enum PlanPhase: String, Codable { case base, development, specific, taper }

struct PlanTimeline {
    let totalWeeks: Int
    let taperWeeks: Int
    let hasGoal: Bool

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

    /// Cycles de 3 semaines croissantes puis 1 de décharge. Affûtage réduit.
    func volumeFactor(of week: Int) -> Double {
        if hasGoal, phase(of: week) == .taper {
            let idx = week - (totalWeeks - taperWeeks)      // 0 = première semaine d'affûtage
            return idx == taperWeeks - 1 ? 0.55 : 0.75
        }
        let pos = week % 4
        return pos == 3 ? 0.75 : 1.0 + 0.08 * Double(pos)
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
    static func slots(for c: PlanConstraints, phase: PlanPhase, week: Int, goal: RaceGoal?) -> [SessionSlot] {
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
            if t == .shortIntervals { variant = shortVariants[week % 3] }
            if t == .longIntervals {
                let useRacePace = (phase == .specific && goal?.targetSeconds != nil)
                variant = useRacePace ? RunVariant.racePace : longVariants[week % 3]
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
        case 2: focuses = [.legs, (week % 2 == 0) ? StrengthFocus.push : StrengthFocus.pull]
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
                if d == 1, a.slot.isHard, b.slot.isHard { p += 100 }         // jamais deux séances dures d'affilée
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

    /// Teste tous les placements possibles (5 040 au maximum pour 7 jours) et garde le meilleur.
    static func place(_ slots: [SessionSlot], fixed: [PlacedSlot] = [], freeDays: [Int]) -> [PlacedSlot] {
        guard !slots.isEmpty, slots.count <= freeDays.count else { return [] }
        var best: [PlacedSlot] = []
        var bestScore = Int.max
        var current: [PlacedSlot] = []
        var used = Set<Int>()

        func search(_ i: Int) {
            if i == slots.count {
                let score = penalty(fixed + current)
                if score < bestScore {
                    bestScore = score
                    best = current
                }
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
        return best
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
        guard let goal = c.goal else { return PlanTimeline(totalWeeks: 4, taperWeeks: 0, hasGoal: false) }
        let days = calendar.dateComponents([.day], from: start, to: goal.date).day ?? 0
        let weeks = min(max((days + 6) / 7, 1), 24)
        return PlanTimeline(totalWeeks: weeks, taperWeeks: goal.distance.taperWeeks, hasGoal: true)
    }

    static func generatePlan(constraints c: PlanConstraints, start: Date,
                             calendar: Calendar = .current) -> [PlannedWeek] {
        let tl = timeline(for: c, start: start, calendar: calendar)
        return (0..<tl.totalWeeks).map { w in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: w, to: start) ?? start
            return generateWeek(week: w, weekStart: weekStart, constraints: c, timeline: tl, calendar: calendar)
        }
    }

    /// Les séances verrouillées gardent leur jour et consomment un créneau du même sport :
    /// une régénération ne refait que le reste de la semaine.
    static func generateWeek(week: Int, weekStart: Date, constraints c: PlanConstraints,
                             timeline tl: PlanTimeline, locked: [TrainingSession] = [],
                             calendar: Calendar = .current) -> PlannedWeek {
        let phase = tl.phase(of: week)
        var slots = PlanComposer.slots(for: c, phase: phase, week: week, goal: c.goal)

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
        let created = PlanPlacer.place(slots, fixed: fixed, freeDays: freeDays).map { p -> TrainingSession in
            let date = calendar.date(byAdding: .day, value: p.day, to: weekStart) ?? weekStart
            return TrainingSession(date: date, kind: p.slot.kind, variant: p.slot.variant,
                                   durationMin: PlanComposer.duration(p.slot, factor: factor))
        }
        return PlannedWeek(index: week, phase: phase, sessions: (locked + created).sorted { $0.date < $1.date })
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
