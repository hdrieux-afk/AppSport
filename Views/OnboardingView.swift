// OnboardingView.swift
// Première utilisation : l'utilisateur renseigne son profil, ses contraintes et son objectif,
// puis l'app propose un plan. Les valeurs par défaut servent d'exemple et sont à modifier.

import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    // Profil
    @State private var vma = 15.0
    @State private var maxHR = 190
    @State private var hasBand = true

    // Contraintes
    @State private var runs = 3
    @State private var bikes = 1
    @State private var strengths = 1
    @State private var venue: Venue = .home

    // Objectif
    @State private var hasGoal = true
    @State private var distance: RaceDistance = .tenK
    @State private var raceDate = Calendar.current.date(byAdding: .weekOfYear, value: 9, to: Date()) ?? Date()
    @State private var hours = 0
    @State private var minutes = 45
    @State private var seconds = 0

    // Volume actuel et préremplissage
    @State private var longRun = 60
    @State private var prefilled = false

    // Valeurs calculées à partir de la saisie
    private var targetSeconds: Double? {
        let total = hours * 3600 + minutes * 60 + seconds
        return total > 0 ? Double(total) : nil
    }
    private var goal: RaceGoal? {
        hasGoal ? RaceGoal(distance: distance, date: raceDate, targetSeconds: targetSeconds) : nil
    }
    private var profile: AthleteProfile {
        AthleteProfile(vmaKmh: vma, maxHR: maxHR, hasBand: hasBand)
    }
    private var constraints: PlanConstraints {
        PlanConstraints(runs: runs, bikes: bikes, strengths: strengths, strengthVenue: venue,
                        goal: goal, currentLongRunMinutes: longRun)
    }
    private var canCreate: Bool { constraints.isValid && profile.isVMAValid }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpace.xl) {
                    DSScreenHeader(title: "Mon plan", subtitle: "Quelques réponses pour construire votre plan")

                    profileSection
                    sessionsSection
                    volumeSection
                    strengthSection
                    goalSection

                    Button("Voir le plan proposé") {
                        store.createDraft(profile: profile, constraints: constraints)
                    }
                    .buttonStyle(.dsPrimary)
                    .disabled(!canCreate)
                    .opacity(canCreate ? 1 : 0.4)
                }
                .padding(.horizontal, DSSpace.l)
                .padding(.bottom, DSSpace.xxl)
            }
            .background(DSColor.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { prefill() }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DSSectionLabel(text: "Profil sportif")
            DSFieldRow(label: "VMA (km/h)") {
                TextField("15", value: $vma, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(DSFont.headline)
                    .frame(width: 90)
            }
            DSFieldRow(label: "FC max (bpm)") {
                TextField("190", value: $maxHR, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(DSFont.headline)
                    .frame(width: 90)
            }
            if !profile.isVMAValid {
                Text("La VMA doit être comprise entre 8 et 25 km/h.")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.accentText)
                    .padding(.top, DSSpace.s)
            }
        }
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DSSectionLabel(text: "Séances par semaine")
            DSStepperRow(label: "Course", value: $runs, range: 0...7)
            DSStepperRow(label: "Vélo", value: $bikes, range: 0...7)
            DSStepperRow(label: "Muscu", value: $strengths, range: 0...7)
            DSLabeledRow(label: "Total", value: "\(constraints.total) séances")
            if !constraints.isValid {
                Text("Choisissez entre 2 et 7 séances au total.")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.accentText)
                    .padding(.top, DSSpace.s)
            }
        }
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: DSSpace.s) {
            DSSectionLabel(text: "Volume actuel")
            DSStepperRow(label: "Sortie la plus longue", value: $longRun, range: 30...180, step: 5, unit: " min")
            Text("Durée de votre sortie de course la plus longue ces 4 dernières semaines. Le plan démarre à ce niveau et monte progressivement, sans dépasser 10 % de hausse par semaine.")
                .ds(.footnote)
        }
    }

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: DSSpace.s) {
            DSSectionLabel(text: "Muscu")
            Picker("Lieu", selection: $venue) {
                Text("Maison").tag(Venue.home)
                Text("Salle").tag(Venue.gym)
            }
            .pickerStyle(.segmented)
            Toggle(isOn: $hasBand) {
                Text("J'ai un élastique").ds(.body)
            }
            .padding(.vertical, DSSpace.s)
            DSHairline()
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DSSectionLabel(text: "Objectif course")
            Toggle(isOn: $hasGoal) {
                Text("J'ai un objectif").ds(.body)
            }
            .padding(.vertical, DSSpace.s)
            DSHairline()

            if hasGoal {
                DSFieldRow(label: "Distance") {
                    Picker("Distance", selection: $distance) {
                        ForEach(RaceDistance.allCases, id: \.self) { d in
                            Text(d.label).tag(d)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                DSFieldRow(label: "Date de la course") {
                    DatePicker("Date de la course", selection: $raceDate, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                }
                DSStepperRow(label: "Temps visé, heures", value: $hours, range: 0...6, unit: " h")
                DSStepperRow(label: "Minutes", value: $minutes, range: 0...59, unit: " min")
                DSStepperRow(label: "Secondes", value: $seconds, range: 0...55, step: 5, unit: " s")

                if let g = goal {
                    DSFeasibility(goal: g, vmaKmh: vma)
                }
                ForEach(constraints.warnings(), id: \.self) { warning in
                    DSBanner(text: warning)
                }
            }
        }
    }

    /// Reprend les dernières réponses si l'utilisateur revient en arrière depuis le plan proposé.
    private func prefill() {
        guard !prefilled else { return }
        prefilled = true
        if let p = store.lastProfile {
            vma = p.vmaKmh
            maxHR = p.maxHR
            hasBand = p.hasBand
        }
        if let c = store.lastConstraints {
            runs = c.runs
            bikes = c.bikes
            strengths = c.strengths
            venue = c.strengthVenue
            longRun = c.currentLongRunMinutes
            if let g = c.goal {
                hasGoal = true
                distance = g.distance
                raceDate = g.date
                if let t = g.targetSeconds {
                    let total = Int(t)
                    hours = total / 3600
                    minutes = (total % 3600) / 60
                    seconds = total % 60
                }
            } else {
                hasGoal = false
            }
        }
    }
}
