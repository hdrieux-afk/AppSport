// PlanProposalView.swift
// Écran "Plan proposé" : l'utilisateur voit le résumé, la montée en charge et la première semaine,
// puis valide, demande une autre disposition, ou revient modifier ses réponses.

import SwiftUI

struct PlanProposalView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            if let draft = store.draft {
                List {
                    summarySection(draft)

                    Section("Volume par semaine, en minutes") {
                        WeeklyVolumeChart(weeks: draft.weeks)
                            .padding(.vertical, 4)
                    }

                    if let first = draft.weeks.first {
                        Section("Semaine 1, \(first.phase.label)") {
                            ForEach(0..<7, id: \.self) { day in
                                ProposalDayRow(week: first, day: day, startDate: draft.startDate)
                            }
                        }
                    }

                    Section {
                        Button { store.confirmDraft() } label: {
                            Text("Valider le plan").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button { store.regenerateDraft() } label: {
                            Label("Proposer une autre disposition", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }

                        Button(role: .cancel) { store.discardDraft() } label: {
                            Text("Modifier mes réponses").frame(maxWidth: .infinity)
                        }
                    } footer: {
                        Text("Vous pourrez ensuite modifier, déplacer ou annuler chaque séance.")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Theme.cream)
                .navigationTitle("Plan proposé")
            }
        }
    }

    @ViewBuilder
    private func summarySection(_ draft: DraftPlan) -> some View {
        Section("Résumé") {
            LabeledContent("Durée du plan", value: "\(draft.weeks.count) semaines")
            LabeledContent("Séances par semaine", value: "\(draft.constraints.total)")
            LabeledContent("Début", value: draft.startDate.fr(.dateTime.day().month(.wide)))
            if let goal = draft.constraints.goal {
                FeasibilityBadge(goal: goal, vmaKmh: draft.profile.vmaKmh)
            }
            ForEach(draft.constraints.warnings(), id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Theme.terracotta)
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
        HStack(spacing: 12) {
            Text(date.fr(.dateTime.weekday(.abbreviated).day()))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .frame(width: 56, alignment: .leading)

            if sessions.isEmpty {
                Text("Repos").foregroundStyle(Theme.muted)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sessions) { session in
                        SessionRow(session: session)
                    }
                }
            }
        }
    }
}
