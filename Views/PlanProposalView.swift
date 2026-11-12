// PlanProposalView.swift
// Écran "Plan proposé" : l'utilisateur voit le résumé, la montée en charge et la première semaine,
// puis valide, demande une autre disposition, ou revient modifier ses réponses.

import SwiftUI

struct PlanProposalView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            if let draft = store.draft {
                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpace.xl) {
                        DSScreenHeader(title: "Plan proposé",
                                       subtitle: "\(draft.weeks.count) semaines, \(draft.constraints.total) séances par semaine")

                        summary(draft)

                        VStack(alignment: .leading, spacing: DSSpace.s) {
                            DSSectionLabel(text: "Volume par semaine, en minutes")
                            DSVolumeChart(weeks: draft.weeks)
                        }

                        if let first = draft.weeks.first {
                            VStack(alignment: .leading, spacing: 0) {
                                DSSectionLabel(text: "Semaine 1, \(first.phase.label)")
                                DSHairline()
                                ForEach(0..<7, id: \.self) { day in
                                    ProposalDayRow(week: first, day: day, startDate: draft.startDate)
                                    DSHairline()
                                }
                            }
                        }

                        VStack(spacing: DSSpace.s) {
                            Button("Valider le plan") { store.confirmDraft() }
                                .buttonStyle(.dsPrimary)
                            Button("Proposer une autre disposition") { store.regenerateDraft() }
                                .buttonStyle(.dsSecondary)
                            Button("Modifier mes réponses") { store.discardDraft() }
                                .buttonStyle(.dsSecondary)
                            Text("Vous pourrez ensuite modifier, déplacer ou annuler chaque séance.")
                                .ds(.footnote)
                                .padding(.top, DSSpace.xs)
                        }
                    }
                    .padding(.horizontal, DSSpace.l)
                    .padding(.bottom, DSSpace.xxl)
                }
                .background(DSColor.background.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    private func summary(_ draft: DraftPlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DSSectionLabel(text: "Résumé")
            DSLabeledRow(label: "Durée du plan", value: "\(draft.weeks.count) semaines")
            DSLabeledRow(label: "Séances par semaine", value: "\(draft.constraints.total)")
            DSLabeledRow(label: "Début", value: draft.startDate.fr(.dateTime.day().month(.wide)))
            if let goal = draft.constraints.goal {
                DSFeasibility(goal: goal, vmaKmh: draft.profile.vmaKmh)
            }
            ForEach(draft.constraints.warnings(), id: \.self) { warning in
                DSBanner(text: warning)
            }
        }
    }
}

/// Une ligne par jour de la première semaine, en lecture seule.
private struct ProposalDayRow: View {
    let week: PlannedWeek
    let day: Int
    let startDate: Date

    private var date: Date {
        Calendar.current.date(byAdding: .day, value: week.index * 7 + day, to: startDate) ?? startDate
    }

    private var sessions: [TrainingSession] {
        week.sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        HStack(spacing: DSSpace.m) {
            Text(date.fr(.dateTime.weekday(.abbreviated).day()))
                .ds(.footnote)
                .frame(width: 64, alignment: .leading)

            if sessions.isEmpty {
                Text("Repos").ds(.footnote)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: DSSpace.s) {
                    ForEach(sessions) { session in
                        DSSessionRow(session: session)
                    }
                }
            }
        }
        .padding(.vertical, DSSpace.m)
    }
}
