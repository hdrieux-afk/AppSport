// PlanView.swift
// Onglet "Plan" : toutes les semaines, jour par jour. On peut ouvrir une séance,
// ajouter une séance sur un jour de repos, ou régénérer une semaine.

import SwiftUI

struct PlanView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSSpace.xl) {
                DSScreenHeader(title: "Plan")

                ForEach(store.weeks) { week in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            DSSectionLabel(text: "Semaine \(week.index + 1), \(week.phase.label)")
                            Spacer()
                            Button {
                                store.regenerateWeek(week.index)
                            } label: {
                                Text("Régénérer").underline()
                            }
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.textPrimary)
                        }
                        DSHairline()
                        ForEach(0..<7, id: \.self) { day in
                            DayRow(week: week, day: day)
                            DSHairline()
                        }
                    }
                }
            }
            .padding(.horizontal, DSSpace.l)
            .padding(.bottom, DSSpace.xxl)
        }
        .background(DSColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
        HStack(alignment: .center, spacing: DSSpace.m) {
            Text(date.fr(.dateTime.weekday(.abbreviated).day()))
                .ds(.footnote)
                .frame(width: 64, alignment: .leading)

            if sessions.isEmpty {
                restRow
            } else {
                VStack(alignment: .leading, spacing: DSSpace.s) {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(sessionID: session.id)
                        } label: {
                            DSSessionRow(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, DSSpace.m)
    }

    private var restRow: some View {
        HStack {
            Text("Repos").ds(.footnote)
            Spacer()
            Menu {
                ForEach(SessionKind.choices(venue: store.constraints?.strengthVenue ?? .home), id: \.title) { kind in
                    Button(kind.title) {
                        store.addSession(weekIndex: week.index, day: day, kind: kind)
                    }
                }
            } label: {
                Label("Ajouter", systemImage: "plus")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textPrimary)
            }
        }
    }
}
