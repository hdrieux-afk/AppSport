// PlanGeneratorTests.swift
// Tests automatiques des règles du plan : placement, progression, faisabilité, séances verrouillées.
// Ils tournent à chaque dépôt de code (Linux et macOS). Remplacer AppSport par le nom du module si besoin.

import XCTest
@testable import AppSport

final class PlanGeneratorTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }

    /// Lundi 16 novembre 2026.
    private var monday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 16)) ?? Date()
    }

    private func dayIndex(_ s: TrainingSession, weekStart: Date) -> Int {
        calendar.dateComponents([.day], from: weekStart, to: s.date).day ?? 0
    }

    // MARK: - Placement

    /// Pour toutes les répartitions possibles de 2 à 7 séances, la semaine contient le bon nombre de séances
    /// et deux séances dures ne sont jamais le même jour ni deux jours de suite (semaine cyclique).
    func testEveryCombinationFillsTheWeekWithoutConsecutiveHardSessions() {
        for runs in 0...7 {
            for bikes in 0...7 {
                for strengths in 0...7 {
                    let total = runs + bikes + strengths
                    guard (2...7).contains(total) else { continue }

                    let c = PlanConstraints(runs: runs, bikes: bikes, strengths: strengths)
                    let timeline = PlanGenerator.timeline(for: c, start: monday, calendar: calendar)
                    // Semaine 3 : phase de développement, celle qui compte le plus de séances dures.
                    let week = PlanGenerator.generateWeek(week: 2, weekStart: monday, constraints: c,
                                                          timeline: timeline, calendar: calendar)
                    let label = "course \(runs), vélo \(bikes), muscu \(strengths)"
                    XCTAssertEqual(week.sessions.count, total, label)

                    let hardDays = week.sessions
                        .filter { SessionSlot(kind: $0.kind, baseDuration: 40).isHard }
                        .map { dayIndex($0, weekStart: monday) }
                    for (i, a) in hardDays.enumerated() {
                        for b in hardDays.dropFirst(i + 1) {
                            let gap = abs(a - b)
                            XCTAssertGreaterThanOrEqual(min(gap, 7 - gap), 2, "séances dures trop proches : \(label)")
                        }
                    }
                }
            }
        }
    }

    /// "Proposer une autre disposition" doit produire au moins une disposition différente.
    func testRegenerationOffersDifferentLayouts() {
        let c = PlanConstraints(runs: 3, bikes: 1, strengths: 1)
        let timeline = PlanGenerator.timeline(for: c, start: monday, calendar: calendar)

        func layout(seed: Int) -> String {
            let week = PlanGenerator.generateWeek(week: 0, weekStart: monday, constraints: c,
                                                  timeline: timeline, seed: seed, calendar: calendar)
            return week.sessions.map { "\(dayIndex($0, weekStart: monday)):\($0.kind)" }.joined(separator: "|")
        }

        let base = layout(seed: 0)
        let others = (1...6).map { layout(seed: $0) }
        XCTAssertTrue(others.contains { $0 != base }, "aucune autre disposition proposée")
    }

    func testLockedSessionsSurviveRegeneration() {
        let c = PlanConstraints(runs: 3, bikes: 1, strengths: 1)
        let timeline = PlanGenerator.timeline(for: c, start: monday, calendar: calendar)
        let first = PlanGenerator.generateWeek(week: 0, weekStart: monday, constraints: c,
                                               timeline: timeline, calendar: calendar)
        var kept = first.sessions[0]
        kept.isLocked = true

        let again = PlanGenerator.generateWeek(week: 0, weekStart: monday, constraints: c, timeline: timeline,
                                               locked: [kept], seed: 3, calendar: calendar)
        XCTAssertTrue(again.sessions.contains { $0.id == kept.id && $0.date == kept.date })
        XCTAssertEqual(again.sessions.count, c.total)
    }

    func testIssuesDetection() {
        let tuesday = TrainingSession(date: monday, kind: .run(.longIntervals), durationMin: 55)
        let wednesday = TrainingSession(date: calendar.date(byAdding: .day, value: 1, to: monday) ?? monday,
                                        kind: .run(.longRun), durationMin: 80)
        XCTAssertEqual(PlanChecks.issues(in: [tuesday, wednesday], weekStart: monday, calendar: calendar),
                       [.consecutiveHardSessions])

        let legs = TrainingSession(date: calendar.date(byAdding: .day, value: 1, to: monday) ?? monday,
                                   kind: .strength(.legs, .home), durationMin: 45)
        XCTAssertEqual(PlanChecks.issues(in: [tuesday, legs], weekStart: monday, calendar: calendar),
                       [.legsNearKeySession])
    }

    // MARK: - Progression

    private func tenKGoal(weeks: Int, targetMinutes: Double = 45) -> RaceGoal {
        RaceGoal(distance: .tenK,
                 date: calendar.date(byAdding: .weekOfYear, value: weeks, to: monday) ?? monday,
                 targetSeconds: targetMinutes * 60)
    }

    func testProgressionShapeForTenKilometres() {
        let c = PlanConstraints(runs: 3, bikes: 1, strengths: 1, goal: tenKGoal(weeks: 9),
                                currentLongRunMinutes: 60)
        let tl = PlanGenerator.timeline(for: c, start: monday, calendar: calendar)

        XCTAssertEqual(tl.totalWeeks, 9)
        XCTAssertEqual(tl.longRunMinutes, [60, 65, 70, 53, 75, 80, 85, 90, 50])
        XCTAssertEqual(tl.deloadWeeks, [3])
        XCTAssertFalse(tl.peakCapped)

        // Aucune décharge dans les 2 dernières semaines de montée avant l'affûtage.
        let body = tl.totalWeeks - tl.taperWeeks
        XCTAssertTrue(tl.deloadWeeks.isDisjoint(with: Set((body - 2)..<body)))
    }

    func testWeeklyGrowthNeverExceedsTenPercent() {
        for start in [30, 45, 60, 90] {
            let c = PlanConstraints(runs: 3, bikes: 1, strengths: 1, goal: tenKGoal(weeks: 12),
                                    currentLongRunMinutes: start)
            let tl = PlanGenerator.timeline(for: c, start: monday, calendar: calendar)
            let body = tl.totalWeeks - tl.taperWeeks
            let build = (0..<body).filter { !tl.deloadWeeks.contains($0) }.map { tl.longRunMinutes[$0] }
            for (a, b) in zip(build, build.dropFirst()) {
                XCTAssertLessThanOrEqual(Double(b), Double(a) * 1.10 + 1.0, "départ \(start) min : \(a) puis \(b)")
            }
        }
    }

    func testBeginnerCannotReachThePeakInNineWeeks() {
        let c = PlanConstraints(runs: 3, bikes: 1, strengths: 1, goal: tenKGoal(weeks: 9),
                                currentLongRunMinutes: 30)
        let tl = PlanGenerator.timeline(for: c, start: monday, calendar: calendar)
        XCTAssertTrue(tl.peakCapped)
    }

    // MARK: - Faisabilité

    func testFeasibilityLevelsForTenKilometres() {
        func level(_ minutes: Double) -> Feasibility? {
            let goal = RaceGoal(distance: .tenK, date: monday, targetSeconds: minutes * 60)
            return assessFeasibility(goal, vmaKmh: 15)?.level
        }
        XCTAssertEqual(level(48), .cautious)
        XCTAssertEqual(level(45), .realistic)
        XCTAssertEqual(level(43), .ambitious)
        XCTAssertEqual(level(40), .veryAmbitious)
    }

    // MARK: - Sauvegardes et replanification

    /// Une sauvegarde d'une ancienne version, sans les champs ajoutés depuis, doit rester lisible.
    func testOldSavedSessionStillDecodes() throws {
        let session = TrainingSession(date: Date(timeIntervalSince1970: 1_800_000_000),
                                      kind: .run(.longRun), durationMin: 80)
        var object = (try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any]) ?? [:]
        for key in ["isDone", "fitRevision", "isLocked", "level", "status", "id", "variant"] {
            object.removeValue(forKey: key)
        }
        let old = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(TrainingSession.self, from: old)
        XCTAssertEqual(decoded.durationMin, 80)
        XCTAssertEqual(decoded.kind, .run(.longRun))
        XCTAssertFalse(decoded.isDone)
        XCTAssertFalse(decoded.isLocked)
        XCTAssertEqual(decoded.status, .planned)
        XCTAssertEqual(decoded.level, .planned)
        XCTAssertEqual(decoded.fitRevision, 0)
    }

    func testOldSavedConstraintsStillDecode() throws {
        let constraints = PlanConstraints(runs: 3, bikes: 1, strengths: 1)
        var object = (try JSONSerialization.jsonObject(with: JSONEncoder().encode(constraints)) as? [String: Any]) ?? [:]
        for key in ["currentLongRunMinutes", "layoutSeed", "strengthVenue", "unavailableWeekdays"] {
            object.removeValue(forKey: key)
        }
        let old = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(PlanConstraints.self, from: old)
        XCTAssertEqual(decoded.total, 5)
        XCTAssertEqual(decoded.currentLongRunMinutes, 60)
        XCTAssertEqual(decoded.layoutSeed, 0)
        XCTAssertEqual(decoded.strengthVenue, .home)
    }

    /// Après un changement d'objectif, le passé, les séances faites et les séances modifiées à la main restent.
    func testReplanKeepsPastDoneAndLockedSessions() {
        let c = PlanConstraints(runs: 3, bikes: 1, strengths: 1, goal: tenKGoal(weeks: 9), currentLongRunMinutes: 60)
        var weeks = PlanGenerator.generatePlan(constraints: c, start: monday, calendar: calendar)
        weeks[2].sessions[0].isDone = true
        weeks[2].sessions[1].isLocked = true
        let doneID = weeks[2].sessions[0].id
        let lockedID = weeks[2].sessions[1].id

        // Aujourd'hui : lundi de la semaine 3 (les semaines 1 et 2 sont passées)
        let today = calendar.date(byAdding: .day, value: 14, to: monday) ?? monday
        var changed = c
        changed.goal = tenKGoal(weeks: 12, targetMinutes: 43)

        let replanned = PlanGenerator.replan(weeks: weeks, constraints: changed, startDate: monday,
                                             today: today, calendar: calendar)
        XCTAssertEqual(replanned.count, 12)
        XCTAssertEqual(replanned[0].sessions.map { $0.id }, weeks[0].sessions.map { $0.id })
        XCTAssertEqual(replanned[1].sessions.map { $0.id }, weeks[1].sessions.map { $0.id })

        let ids = replanned[2].sessions.map { $0.id }
        XCTAssertTrue(ids.contains(doneID))
        XCTAssertTrue(ids.contains(lockedID))
        XCTAssertEqual(replanned[2].sessions.count, c.total)
    }
}
