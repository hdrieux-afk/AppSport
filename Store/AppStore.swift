// AppStore.swift
// Le "cerveau" de l'app côté interface : il garde le plan en mémoire, expose les actions de l'utilisateur
// (proposer, valider, modifier, changer de sport, déplacer, annuler, marquer faite, régénérer)
// et sauvegarde après chaque changement.
//
// Les vues lisent cet objet et se redessinent toutes seules quand il change (macro @Observable, iOS 17).
// Les règles elles-mêmes (durées, équivalences, placement, vérifications) restent dans le domaine.

import Foundation
import SwiftData
import Observation

/// Plan proposé à l'utilisateur : il n'existe qu'en mémoire tant qu'il n'a pas été validé.
struct DraftPlan {
    var profile: AthleteProfile
    var constraints: PlanConstraints
    var startDate: Date
    var weeks: [PlannedWeek]
}

@Observable
final class AppStore {

    // État visible par les vues
    var profile: AthleteProfile?
    var constraints: PlanConstraints?
    var startDate: Date = Date()
    var weeks: [PlannedWeek] = []
    var draft: DraftPlan?
    var isLoaded = false

    /// Dernières réponses de l'onboarding : elles préremplissent le formulaire si on revient en arrière.
    var lastProfile: AthleteProfile?
    var lastConstraints: PlanConstraints?

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

    // MARK: - Proposition de plan, puis validation

    /// Génère un plan à partir de l'onboarding. Il reste un brouillon tant que l'utilisateur ne le valide pas.
    func createDraft(profile: AthleteProfile, constraints: PlanConstraints) {
        lastProfile = profile
        lastConstraints = constraints
        let start = PlanGenerator.nextMonday(from: Date())
        draft = DraftPlan(profile: profile, constraints: constraints, startDate: start,
                          weeks: PlanGenerator.generatePlan(constraints: constraints, start: start))
    }

    /// Propose une autre disposition (jours, variantes de séances) sans changer les contraintes.
    func regenerateDraft() {
        guard var current = draft else { return }
        current.constraints.layoutSeed += 1
        current.weeks = PlanGenerator.generatePlan(constraints: current.constraints, start: current.startDate)
        draft = current
    }

    /// Valide le brouillon : il devient le plan de l'app et il est sauvegardé.
    func confirmDraft() {
        guard let current = draft else { return }
        profile = current.profile
        constraints = current.constraints
        startDate = current.startDate
        weeks = current.weeks
        draft = nil
        save()
    }

    /// Revient à l'onboarding (les réponses restent préremplies).
    func discardDraft() {
        draft = nil
    }

    /// Création directe, sans passer par la proposition (mode démo).
    func createPlan(profile: AthleteProfile, constraints: PlanConstraints) {
        createDraft(profile: profile, constraints: constraints)
        confirmDraft()
    }

    // MARK: - Modes démo (captures d'écran de l'intégration continue)

    private func demoInputs() -> (AthleteProfile, PlanConstraints) {
        let raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 9, to: Date()) ?? Date()
        let goal = RaceGoal(distance: .tenK, date: raceDate, targetSeconds: 45 * 60)
        return (AthleteProfile(vmaKmh: 15, maxHR: 190, hasBand: true),
                PlanConstraints(runs: 3, bikes: 1, strengths: 1, strengthVenue: .home,
                                goal: goal, currentLongRunMinutes: 60))
    }

    /// Lancement avec l'argument -demo : plan d'exemple déjà validé.
    func createDemoPlan() {
        let (p, c) = demoInputs()
        createPlan(profile: p, constraints: c)
    }

    /// Lancement avec l'argument -demoDraft : plan d'exemple en attente de validation.
    func createDemoDraft() {
        let (p, c) = demoInputs()
        createDraft(profile: p, constraints: c)
    }

    // MARK: - Régénération d'une semaine

    /// Régénère une semaine : les séances verrouillées ou faites sont conservées.
    func regenerateWeek(_ index: Int) {
        guard let constraints = constraints, weeks.indices.contains(index) else { return }
        let timeline = PlanGenerator.timeline(for: constraints, start: startDate)
        let kept = weeks[index].sessions.filter { $0.isLocked || $0.isDone }
        weeks[index] = PlanGenerator.generateWeek(week: index, weekStart: weekStart(index: index),
                                                  constraints: constraints, timeline: timeline,
                                                  locked: kept, seed: Int.random(in: 1...1000))
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

    func setDone(_ id: UUID, _ done: Bool) {
        mutate(id) { $0.setDone(done) }
    }

    /// Déplace une séance sur un autre jour de la même semaine (0 = lundi ... 6 = dimanche).
    func move(_ id: UUID, toDay day: Int) {
        guard let start = weekStart(of: id) else { return }
        let date = Calendar.current.date(byAdding: .day, value: day, to: start) ?? start
        mutate(id) { $0.move(to: date) }
        for w in weeks.indices {
            weeks[w].sessions.sort { $0.date < $1.date }
        }
        save()
    }

    /// Problèmes de placement qu'un déplacement créerait, pour prévenir l'utilisateur sans l'empêcher.
    func issuesAfterMoving(_ id: UUID, toDay day: Int) -> [PlanIssue] {
        guard let w = weeks.firstIndex(where: { week in week.sessions.contains { $0.id == id } }) else { return [] }
        let start = weekStart(index: w)
        var sessions = weeks[w].sessions
        guard let s = sessions.firstIndex(where: { $0.id == id }) else { return [] }
        sessions[s].date = Calendar.current.date(byAdding: .day, value: day, to: start) ?? start
        return PlanChecks.issues(in: sessions, weekStart: start)
    }

    /// Ajoute une séance sur un jour de repos. Elle est verrouillée d'emblée.
    func addSession(weekIndex: Int, day: Int, kind: SessionKind) {
        guard weeks.indices.contains(weekIndex) else { return }
        let date = Calendar.current.date(byAdding: .day, value: day, to: weekStart(index: weekIndex)) ?? startDate

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
        draft = nil
    }

    // MARK: - Dates

    func weekStart(index: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: index, to: startDate) ?? startDate
    }

    func weekStart(of id: UUID) -> Date? {
        guard let w = weeks.firstIndex(where: { week in week.sessions.contains { $0.id == id } }) else { return nil }
        return weekStart(index: w)
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
