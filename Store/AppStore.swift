// AppStore.swift
// Le "cerveau" de l'app côté interface : il garde le plan en mémoire, expose les actions de l'utilisateur
// (créer, modifier, changer de sport, annuler, régénérer) et sauvegarde après chaque changement.
//
// Les vues lisent cet objet et se redessinent toutes seules quand il change (macro @Observable, iOS 17).
// Les règles elles-mêmes (durées, équivalences, placement) restent dans le domaine.

import Foundation
import SwiftData
import Observation

@Observable
final class AppStore {

    // État visible par les vues
    var profile: AthleteProfile?
    var constraints: PlanConstraints?
    var startDate: Date = Date()
    var weeks: [PlannedWeek] = []
    var isLoaded = false

    // Détails internes, ignorés par l'observation
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var entity: PlanEntity?

    var goal: RaceGoal? { constraints?.goal }

    // MARK: - Chargement

    /// Branche le store sur la base SwiftData et recharge le plan sauvegardé, s'il existe.
    func attach(_ context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context

        if let existing = try? context.fetch(FetchDescriptor<PlanEntity>()).first {
            entity = existing
            let decoder = JSONDecoder()
            profile = try? decoder.decode(AthleteProfile.self, from: existing.profileData)
            constraints = try? decoder.decode(PlanConstraints.self, from: existing.constraintsData)
            weeks = (try? decoder.decode([PlannedWeek].self, from: existing.weeksData)) ?? []
            startDate = existing.startDate
        }
        isLoaded = true
    }

    // MARK: - Création et régénération

    /// Génère un plan à partir du profil et des contraintes saisis à l'onboarding.
    func createPlan(profile: AthleteProfile, constraints: PlanConstraints) {
        self.profile = profile
        self.constraints = constraints
        startDate = PlanGenerator.nextMonday(from: Date())
        weeks = PlanGenerator.generatePlan(constraints: constraints, start: startDate)
        save()
    }

    /// Plan d'exemple, utilisé par l'intégration continue pour produire des captures d'écran
    /// (l'app est lancée avec l'argument -demo).
    func createDemoPlan() {
        let raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 9, to: Date()) ?? Date()
        let goal = RaceGoal(distance: .tenK, date: raceDate, targetSeconds: 45 * 60)
        createPlan(profile: AthleteProfile(vmaKmh: 15, maxHR: 190, hasBand: true),
                   constraints: PlanConstraints(runs: 3, bikes: 1, strengths: 1,
                                                strengthVenue: .home, goal: goal))
    }

    /// Régénère une semaine : les séances verrouillées (modifiées à la main) sont conservées.
    func regenerateWeek(_ index: Int) {
        guard let constraints = constraints, weeks.indices.contains(index) else { return }
        let timeline = PlanGenerator.timeline(for: constraints, start: startDate)
        let weekStart = Calendar.current.date(byAdding: .weekOfYear, value: index, to: startDate) ?? startDate
        let locked = weeks[index].sessions.filter { $0.isLocked }
        weeks[index] = PlanGenerator.generateWeek(week: index, weekStart: weekStart,
                                                  constraints: constraints, timeline: timeline,
                                                  locked: locked)
        save()
    }

    // MARK: - Actions sur une séance

    func session(_ id: UUID) -> TrainingSession? {
        weeks.flatMap { $0.sessions }.first { $0.id == id }
    }

    func modify(_ id: UUID, durationMin: Int, level: Level) {
        mutate(id) { $0.modify(durationMin: durationMin, level: level) }
    }

    func changeSport(_ id: UUID, to kind: SessionKind) {
        mutate(id) { $0.changeSport(to: kind) }
    }

    func cancel(_ id: UUID) {
        mutate(id) { $0.cancel() }
    }

    /// Ajoute une séance sur un jour de repos. Elle est verrouillée d'emblée.
    func addSession(weekIndex: Int, day: Int, kind: SessionKind) {
        guard weeks.indices.contains(weekIndex) else { return }
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: startDate) ?? startDate
        let date = calendar.date(byAdding: .day, value: day, to: weekStart) ?? weekStart

        var session = TrainingSession(date: date, kind: kind, durationMin: kind.defaultDuration)
        session.status = .modified
        session.isLocked = true

        weeks[weekIndex].sessions.append(session)
        weeks[weekIndex].sessions.sort { $0.date < $1.date }
        save()
    }

    /// Efface le plan (utile pour recommencer l'onboarding pendant les tests).
    func reset() {
        if let entity = entity { context?.delete(entity) }
        try? context?.save()
        entity = nil
        weeks = []
        profile = nil
        constraints = nil
    }

    // MARK: - Interne

    /// Applique un changement à une séance, où qu'elle soit dans le plan, puis sauvegarde.
    private func mutate(_ id: UUID, _ change: (inout TrainingSession) -> Void) {
        for w in weeks.indices {
            if let s = weeks[w].sessions.firstIndex(where: { $0.id == id }) {
                change(&weeks[w].sessions[s])
                save()
                return
            }
        }
    }

    private func save() {
        guard let profile = profile, let constraints = constraints, let context = context else { return }
        let encoder = JSONEncoder()
        guard let p = try? encoder.encode(profile),
              let c = try? encoder.encode(constraints),
              let w = try? encoder.encode(weeks) else { return }

        if let entity = entity {
            entity.profileData = p
            entity.constraintsData = c
            entity.weeksData = w
            entity.startDate = startDate
        } else {
            let created = PlanEntity(createdAt: Date(), startDate: startDate,
                                     profileData: p, constraintsData: c, weeksData: w)
            context.insert(created)
            entity = created
        }
        try? context.save()
    }
}
