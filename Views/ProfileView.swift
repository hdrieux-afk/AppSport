// ProfileView.swift
// Onglet "Profil" : VMA, FC max, zones calculées, objectif, et remise à zéro du plan.

import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmReset = false
    @State private var showEdit = false
    @State private var showWatch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpace.xl) {
                DSScreenHeader(title: "Profil")

                if let p = store.profile {
                    block("Profil sportif") {
                        DSLabeledRow(label: "VMA", value: String(format: "%.1f km/h", p.vmaKmh))
                        DSLabeledRow(label: "FC max", value: "\(p.maxHR) bpm")
                        DSLabeledRow(label: "Élastique", value: p.hasBand ? "Oui" : "Non")
                    }

                    block("Zones de fréquence cardiaque") {
                        ForEach(0..<5, id: \.self) { i in
                            DSLabeledRow(label: "Z\(i + 1)", value: hrZone(p, index: i))
                        }
                    }

                    block("Allures clés") {
                        DSLabeledRow(label: "Endurance", value: paceRange(p, 0.60, 0.75))
                        DSLabeledRow(label: "Seuil", value: paceRange(p, 0.80, 0.88))
                        DSLabeledRow(label: "VMA", value: paceRange(p, 0.95, 1.05))
                    }

                    if let goal = store.goal {
                        block("Objectif") {
                            DSLabeledRow(label: goal.distance.label,
                                         value: goal.date.fr(.dateTime.day().month(.wide).year()))
                            if let target = goal.targetSeconds {
                                DSLabeledRow(label: "Temps visé", value: formatClock(target))
                            }
                            DSFeasibility(goal: goal, vmaKmh: p.vmaKmh)
                        }
                    }
                }

                block("Montre") {
                    DSLabeledRow(label: "Envoi sans câble",
                                 value: store.watchConnected ? "intervals.icu connecté" : "Non connecté")
                    Button(store.watchConnected ? "Gérer l’envoi vers la montre" : "Connecter la montre") {
                        showWatch = true
                    }
                    .buttonStyle(.dsSecondary)
                    .padding(.top, DSSpace.m)
                }

                VStack(spacing: DSSpace.s) {
                    Button("Modifier le profil et l’objectif") { showEdit = true }
                        .buttonStyle(.dsSecondary)
                    Button("Réinitialiser le plan") { confirmReset = true }
                        .buttonStyle(.dsDestructive)
                }
            }
            .padding(.horizontal, DSSpace.l)
            .padding(.bottom, DSSpace.xxl)
        }
        .background(DSColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEdit) {
            if let p = store.profile {
                EditProfileSheet(profile: p, goal: store.goal)
            }
        }
        .sheet(isPresented: $showWatch) { WatchConnectionSheet() }
        .confirmationDialog("Effacer le plan et recommencer ?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Effacer le plan", role: .destructive) { store.reset() }
            Button("Annuler", role: .cancel) {}
        }
    }

    private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DSSectionLabel(text: title)
            DSHairline()
            content()
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
