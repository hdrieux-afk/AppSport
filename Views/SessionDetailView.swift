// SessionDetailView.swift
// Détail d'une séance : étapes et cibles (course, vélo) ou exercices (muscu),
// export du fichier .fit, et les trois actions : modifier, changer de sport, annuler.

import SwiftUI

struct SessionDetailView: View {
    @Environment(AppStore.self) private var store
    let sessionID: UUID

    @State private var showModify = false
    @State private var showChangeSport = false
    @State private var showMove = false
    @State private var confirmCancel = false
    @State private var fitURL: URL?

    var body: some View {
        Group {
            if let session = store.session(sessionID), let profile = store.profile {
                content(session, profile)
            } else {
                Text("Séance introuvable").foregroundStyle(Theme.muted)
            }
        }
        .background(Theme.cream)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Contenu

    @ViewBuilder
    private func content(_ session: TrainingSession, _ profile: AthleteProfile) -> some View {
        // Le domaine transforme la séance du plan en étapes (endurance) ou en exercices (muscu).
        let built = session.render(profile: profile, goal: store.goal)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(session)

                if session.status == .cancelled {
                    Text("Séance annulée : elle compte comme un jour de repos.")
                        .card()
                } else {
                    switch built {
                    case .endurance(let workout):
                        enduranceSection(session, workout)
                    case .strength(let workout):
                        strengthSection(workout)
                    }
                    actions(session)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showModify) { ModifySessionSheet(session: session) }
        .sheet(isPresented: $showChangeSport) { ChangeSportSheet(session: session) }
        .sheet(isPresented: $showMove) { MoveSessionSheet(session: session) }
    }

    private func header(_ session: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            Text(session.kind.title)
                .font(Theme.title(26))
            Text(headerSubtitle(session))
                .foregroundStyle(Theme.muted)
        }
    }

    private func headerSubtitle(_ session: TrainingSession) -> String {
        var parts = ["\(session.durationMin) min", session.kind.sport.label]
        if session.kind.role == .key { parts.append("séance clé") }
        if session.status == .modified { parts.append("modifiée") }
        if session.isDone { parts.append("faite") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Endurance

    private func enduranceSection(_ session: TrainingSession, _ workout: EnduranceWorkout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            WorkoutProfileBar(workout: workout)

            ForEach(Array(workout.items.enumerated()), id: \.offset) { _, item in
                itemView(item, sport: workout.sport)
            }

            if let notes = workout.notes {
                Text(notes).font(.footnote).foregroundStyle(Theme.muted)
            }

            exportBlock(session, workout)
        }
        .card()
    }

    @ViewBuilder
    private func itemView(_ item: WorkoutItem, sport: Sport) -> some View {
        switch item {
        case .step(let step):
            stepRow(step, sport: sport)
        case .repeatBlock(let count, let steps):
            VStack(alignment: .leading, spacing: 6) {
                Text("\(count) fois")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    stepRow(step, sport: sport)
                }
            }
            .padding(.leading, 8)
        }
    }

    private func stepRow(_ step: WorkoutStep, sport: Sport) -> some View {
        HStack {
            Circle()
                .fill(sport.color.opacity(step.intensity.opacity))
                .frame(width: 10, height: 10)
            Text(step.intensity.label)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(describe(step.duration))
                Text(describe(step.target))
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    /// Le fichier .fit est régénéré à chaque modification : la tâche se relance quand la révision change.
    private func exportBlock(_ session: TrainingSession, _ workout: EnduranceWorkout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = fitURL {
                ShareLink(item: url) {
                    Label("Exporter le fichier .fit", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            Text("Fichier version v\(session.fitRevision + 1). Après une modification, renvoyez-le vers la montre.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .task(id: session.fitRevision) {
            fitURL = try? FitExport.writeTemporaryFile(session: session, workout: workout)
        }
    }

    // MARK: - Muscu

    private func strengthSection(_ workout: StrengthWorkout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(workout.warmup)
                .font(.footnote)
                .foregroundStyle(Theme.muted)

            ForEach(Array(workout.items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.exercise.name)
                        Spacer()
                        Text("\(item.sets) × \(item.scheme.text)")
                            .foregroundStyle(Theme.muted)
                    }
                    if let note = item.exercise.safetyNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(Theme.terracotta)
                    }
                }
            }

            Label("Pas de fichier montre pour la muscu : séance à suivre dans l’app.",
                  systemImage: "info.circle")
                .font(.footnote)
                .padding(.top, 4)
        }
        .card()
    }

    // MARK: - Actions

    private func actions(_ session: TrainingSession) -> some View {
        VStack(spacing: 10) {
            Button { store.setDone(session.id, !session.isDone) } label: {
                Label(session.isDone ? "Remettre à faire" : "Marquer comme faite",
                      systemImage: session.isDone ? "arrow.uturn.backward" : "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button { showModify = true } label: {
                Label("Modifier la séance", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button { showChangeSport = true } label: {
                Label("Changer de sport", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button { showMove = true } label: {
                Label("Déplacer", systemImage: "calendar.badge.clock")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) { confirmCancel = true } label: {
                Label("Annuler la séance", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .confirmationDialog("Annuler cette séance ?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Annuler la séance", role: .destructive) { store.cancel(session.id) }
            Button("Garder", role: .cancel) {}
        }
    }
}
