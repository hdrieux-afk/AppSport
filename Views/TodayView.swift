// TodayView.swift
// Onglet "Aujourd'hui" : la prochaine séance en grand, puis les suivantes.

import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store

    /// Séances à partir d'aujourd'hui, hors annulées, dans l'ordre.
    private var upcoming: [TrainingSession] {
        let start = Calendar.current.startOfDay(for: Date())
        return store.weeks
            .flatMap { $0.sessions }
            .filter { $0.date >= start && $0.status != .cancelled && !$0.isDone }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let next = upcoming.first {
                    Text(Calendar.current.isDateInToday(next.date) ? "Aujourd’hui" : "Prochaine séance")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)

                    NavigationLink {
                        SessionDetailView(sessionID: next.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(next.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                            SessionRow(session: next)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)

                    Text("À venir")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 8)

                    ForEach(Array(upcoming.dropFirst().prefix(4))) { session in
                        NavigationLink {
                            SessionDetailView(sessionID: session.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                                SessionRow(session: session)
                            }
                            .card()
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Plan terminé, bravo !")
                        .font(Theme.title(20))
                }
            }
            .padding()
        }
        .background(Theme.cream)
        .navigationTitle("Aujourd’hui")
    }
}
