// EditProfileSheet.swift
// Modification de la VMA, de la FC max, de l'élastique et de l'objectif course.
// À l'enregistrement, le plan est replanifié à partir d'aujourd'hui : le passé et les séances
// faites ou modifiées à la main sont conservés.

import SwiftUI

struct EditProfileSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var vma: Double
    @State private var maxHR: Int
    @State private var hasBand: Bool
    @State private var hasGoal: Bool
    @State private var distance: RaceDistance
    @State private var raceDate: Date
    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int

    init(profile: AthleteProfile, goal: RaceGoal?) {
        let total = Int(goal?.targetSeconds ?? 0)
        _vma = State(initialValue: profile.vmaKmh)
        _maxHR = State(initialValue: profile.maxHR)
        _hasBand = State(initialValue: profile.hasBand)
        _hasGoal = State(initialValue: goal != nil)
        _distance = State(initialValue: goal?.distance ?? .tenK)
        _raceDate = State(initialValue: goal?.date
            ?? (Calendar.current.date(byAdding: .weekOfYear, value: 9, to: Date()) ?? Date()))
        _hours = State(initialValue: total / 3600)
        _minutes = State(initialValue: (total % 3600) / 60)
        _seconds = State(initialValue: total % 60)
    }

    private var profile: AthleteProfile {
        AthleteProfile(vmaKmh: vma, maxHR: maxHR, hasBand: hasBand)
    }

    private var goal: RaceGoal? {
        guard hasGoal else { return nil }
        let total = hours * 3600 + minutes * 60 + seconds
        return RaceGoal(distance: distance, date: raceDate, targetSeconds: total > 0 ? Double(total) : nil)
    }

    var body: some View {
        DSSheetFrame(title: "Modifier le profil") {
            VStack(alignment: .leading, spacing: DSSpace.l) {
                VStack(alignment: .leading, spacing: 0) {
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
                    Toggle(isOn: $hasBand) {
                        Text("J'ai un élastique").ds(.body)
                    }
                    .padding(.vertical, DSSpace.s)
                    DSHairline()
                    if !profile.isVMAValid {
                        Text("La VMA doit être comprise entre 8 et 25 km/h.")
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.accentText)
                            .padding(.top, DSSpace.s)
                    }
                }

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
                    }
                }

                Text("Les séances passées, faites ou modifiées à la main sont conservées. Le reste du plan est recalculé.")
                    .ds(.footnote)

                Button("Enregistrer") {
                    store.updateProfile(profile, goal: goal)
                    dismiss()
                }
                .buttonStyle(.dsPrimary)
                .disabled(!profile.isVMAValid)
                .opacity(profile.isVMAValid ? 1 : 0.4)
            }
        }
    }
}
