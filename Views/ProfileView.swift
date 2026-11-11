// ProfileView.swift
// Onglet "Profil" : VMA, FC max, zones calculées, objectif, et remise à zéro du plan.

import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmReset = false

    var body: some View {
        List {
            if let p = store.profile {
                Section("Profil sportif") {
                    LabeledContent("VMA", value: String(format: "%.1f km/h", p.vmaKmh))
                    LabeledContent("FC max", value: "\(p.maxHR) bpm")
                    LabeledContent("Élastique", value: p.hasBand ? "Oui" : "Non")
                }

                Section("Zones de fréquence cardiaque") {
                    ForEach(0..<5, id: \.self) { i in
                        LabeledContent("Z\(i + 1)", value: hrZone(p, index: i))
                    }
                }

                Section("Allures clés") {
                    LabeledContent("Endurance", value: paceRange(p, 0.60, 0.75))
                    LabeledContent("Seuil", value: paceRange(p, 0.80, 0.88))
                    LabeledContent("VMA", value: paceRange(p, 0.95, 1.05))
                }

                if let goal = store.goal {
                    Section("Objectif") {
                        LabeledContent(goal.distance.label,
                                       value: goal.date.formatted(.dateTime.day().month(.wide).year()))
                        if let target = goal.targetSeconds {
                            LabeledContent("Temps visé", value: formatClock(target))
                        }
                        FeasibilityBadge(goal: goal, vmaKmh: p.vmaKmh)
                    }
                }
            }

            Section {
                Button("Réinitialiser le plan", role: .destructive) { confirmReset = true }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.cream)
        .navigationTitle("Profil")
        .confirmationDialog("Effacer le plan et recommencer ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Effacer le plan", role: .destructive) { store.reset() }
            Button("Annuler", role: .cancel) {}
        }
    }

    /// Zones de FC par tranches de 10 % de la FC max, de 50 % à 100 %.
    private func hrZone(_ p: AthleteProfile, index: Int) -> String {
        let lo = 0.5 + 0.1 * Double(index)
        let low = Int((Double(p.maxHR) * lo).rounded())
        let high = Int((Double(p.maxHR) * (lo + 0.1)).rounded())
        return "\(low)–\(high) bpm"
    }

    /// Fourchette d'allure en min/km pour une plage de pourcentages de VMA.
    private func paceRange(_ p: AthleteProfile, _ lo: Double, _ hi: Double) -> String {
        "\(formatPace(p.vmaKmh * hi / 3.6))–\(formatPace(p.vmaKmh * lo / 3.6)) /km"
    }
}
