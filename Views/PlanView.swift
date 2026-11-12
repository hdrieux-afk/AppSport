// PlanView.swift
// Onglet "Plan" : toutes les semaines, jour par jour. On peut ouvrir une séance,
// ajouter une séance sur un jour de repos, ou régénérer une semaine.

import SwiftUI

struct PlanView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        List {
            ForEach(store.weeks) { week in
                Section {
                    ForEach(0..<7, id: \.self) { day in
                        DayRow(week: week, day: day)
                    }
                } header: {
                    HStack {
                        Text("Semaine \(week.index + 1), \(week.phase.label)")
                        Spacer()
                        Button("Régénérer") { store.regenerateWeek(week.index) }
                            .font(.footnote)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.cream)
        .navigationTitle("Plan")
    }
}

/// Une ligne par jour : la ou les séances du jour, ou "Repos" avec un bouton Ajouter.
private struct DayRow: View {
    @Environment(AppStore.self) private var store
    let week: PlannedWeek
    let day: Int

    private var date: Date {
        Calendar.current.date(byAdding: .day, value: week.index * 7 + day, to: store.startDate) ?? store.startDate
    }

    private var sessions: [TrainingSession] {
        week.sessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(date.fr(.dateTime.weekday(.abbreviated).day()))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .frame(width: 56, alignment: .leading)

            if sessions.isEmpty {
                restRow
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(sessionID: session.id)
                        } label: {
                            SessionRow(session: session)
                        }
                    }
                }
            }
        }
    }

    private var restRow: some View {
        HStack {
            Text("Repos").foregroundStyle(Theme.muted)
            Spacer()
            Menu {
                ForEach(SessionKind.choices(venue: store.constraints?.strengthVenue ?? .home), id: \.title) { kind in
                    Button(kind.title) {
                        store.addSession(weekIndex: week.index, day: day, kind: kind)
                    }
                }
            } label: {
                Label("Ajouter", systemImage: "plus")
                    .font(.footnote)
            }
        }
    }
}
