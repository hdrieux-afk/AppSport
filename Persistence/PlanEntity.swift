// PlanEntity.swift
// Ce que SwiftData sauvegarde sur l'iPhone : un seul enregistrement, le plan complet en JSON.
//
// Pourquoi du JSON plutôt qu'une table par séance ? Le plan est petit, il est lu et écrit en bloc,
// et nos types du domaine (enums avec valeurs associées) sont déjà Codable. On garde ainsi le domaine
// propre, sans le réécrire en classes SwiftData. Quand il faudra un historique des séances réalisées
// (import HealthKit, par exemple), on passera à une table par séance.

import Foundation
import SwiftData

@Model
final class PlanEntity {
    var createdAt: Date
    var startDate: Date          // lundi de la première semaine du plan
    var profileData: Data        // AthleteProfile encodé en JSON
    var constraintsData: Data    // PlanConstraints encodé en JSON
    var weeksData: Data          // [PlannedWeek] encodé en JSON

    init(createdAt: Date, startDate: Date, profileData: Data, constraintsData: Data, weeksData: Data) {
        self.createdAt = createdAt
        self.startDate = startDate
        self.profileData = profileData
        self.constraintsData = constraintsData
        self.weeksData = weeksData
    }
}
