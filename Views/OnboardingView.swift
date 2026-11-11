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
        PlanConstraints(runs: runs, bikes: bikes, strengths: strengths, strengthVenue: venue, goal: goal)
    }
    private var canCreate: Bool { constraints.isValid && profile.isVMAValid }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profil sportif") {
                    HStack {
                        Text("VMA (km/h)")
                        Spacer()
                        TextField("15", value: $vma, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("FC max (bpm)")
                        Spacer()
                        TextField("190", value: $maxHR, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    if !profile.isVMAValid {
                        Text("La VMA doit être comprise entre 8 et 25 km/h.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Séances par semaine") {
                    Stepper("Course : \(runs)", value: $runs, in: 0...7)
                    Stepper("Vélo : \(bikes)", value: $bikes, in: 0...7)
                    Stepper("Muscu : \(strengths)", value: $strengths, in: 0...7)
                    LabeledContent("Total", value: "\(constraints.total) séances")
                    if !constraints.isValid {
                        Text("Choisissez entre 2 et 7 séances au total.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Muscu") {
                    Picker("Lieu", selection: $venue) {
                        Text("Maison").tag(Venue.home)
                        Text("Salle").tag(Venue.gym)
                    }
                    .pickerStyle(.segmented)
                    Toggle("J'ai un élastique", isOn: $hasBand)
                }

                Section("Objectif course") {
                    Toggle("J'ai un objectif", isOn: $hasGoal)
                    if hasGoal {
                        Picker("Distance", selection: $distance) {
                            ForEach(RaceDistance.allCases, id: \.self) { d in
                                Text(d.label).tag(d)
                            }
                        }
                        DatePicker("Date de la course", selection: $raceDate, in: Date()..., displayedComponents: .date)
                        Stepper("Temps visé, heures : \(hours)", value: $hours, in: 0...6)
                        Stepper("Minutes : \(minutes)", value: $minutes, in: 0...59)
                        Stepper("Secondes : \(seconds)", value: $seconds, in: 0...55, step: 5)
                        if let g = goal {
                            FeasibilityBadge(goal: g, vmaKmh: vma)
                        }
                        ForEach(constraints.warnings(), id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(Theme.terracotta)
                        }
                    }
                }

                Section {
                    Button("Proposer un plan") {
                        store.createPlan(profile: profile, constraints: constraints)
                    }
                    .disabled(!canCreate)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .navigationTitle("Mon plan")
        }
    }
}
