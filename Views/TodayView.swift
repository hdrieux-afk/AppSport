// TodayView.swift
// Onglet "Aujourd'hui" : la prochaine séance en grand, puis les suivantes.

import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store

    /// Séances à partir d'aujourd'hui, hors annulées et déjà faites, dans l'ordre.
    private var upcoming: [TrainingSession] {
        let start = Calendar.current.startOfDay(for: Date())
        return store.weeks
            .flatMap { $0.sessions }
            .filter { $0.date >= start && $0.status != .cancelled && !$0.isDone }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpace.xl) {
                DSScreenHeader(title: "Aujourd’hui")

                if let next = upcoming.first {
                    NavigationLink {
                        SessionDetailView(sessionID: next.id)
                    } label: {
                        nextCard(next)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 0) {
                        DSSectionLabel(text: "À venir")
                        DSHairline()
                        ForEach(Array(upcoming.dropFirst().prefix(5))) { session in
                            NavigationLink {
                                SessionDetailView(sessionID: session.id)
                            } label: {
                                upcomingRow(session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("Plan terminé, bravo !").ds(.title)
                }
            }
            .padding(.horizontal, DSSpace.l)
            .padding(.bottom, DSSpace.xxl)
        }
        .background(DSColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func nextCard(_ session: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: DSSpace.s) {
            Text(Calendar.current.isDateInToday(session.date) ? "Aujourd’hui" : "Prochaine séance")
                .ds(.footnote)
            Text(session.kind.title).ds(.display)
            HStack(alignment: .firstTextBaseline, spacing: DSSpace.s) {
                Text("\(session.durationMin)").ds(.hero)
                Text("minutes").ds(.footnote)
                Spacer()
                if session.kind.role == .key {
                    HStack(spacing: DSSpace.xs) {
                        KeyMarker()
                        Text("séance clé").ds(.footnote)
                    }
                }
            }
            Text(session.date.fr(.dateTime.weekday(.wide).day().month(.wide))).ds(.footnote)
            DSHairline().padding(.top, DSSpace.s)
        }
    }

    private func upcomingRow(_ session: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(session.date.fr(.dateTime.weekday(.wide).day().month(.abbreviated)))
                .ds(.caption)
                .padding(.top, DSSpace.m)
            DSSessionRow(session: session)
                .padding(.vertical, DSSpace.s)
            DSHairline()
        }
    }
}
