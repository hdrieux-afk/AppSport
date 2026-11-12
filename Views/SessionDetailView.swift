// SessionDetailView.swift
// Détail d'une séance : étapes et cibles (course, vélo) ou exercices (muscu),
// export du fichier .fit, et les actions : faite, modifier, changer de sport, déplacer, annuler.

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
                Text("Séance introuvable").ds(.footnote)
            }
        }
        .background(DSColor.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Contenu

    @ViewBuilder
    private func content(_ session: TrainingSession, _ profile: AthleteProfile) -> some View {
        // Le domaine transforme la séance du plan en étapes (endurance) ou en exercices (muscu).
        let built = session.render(profile: profile, goal: store.goal)

        ScrollView {
            VStack(alignment: .leading, spacing: DSSpace.xl) {
                header(session)

                if session.status == .cancelled {
                    DSBanner(text: "Séance annulée : elle compte comme un jour de repos.")
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
            .padding(.horizontal, DSSpace.l)
            .padding(.bottom, DSSpace.xxl)
        }
        .sheet(isPresented: $showModify) { ModifySessionSheet(session: session) }
        .sheet(isPresented: $showChangeSport) { ChangeSportSheet(session: session) }
        .sheet(isPresented: $showMove) { MoveSessionSheet(session: session) }
    }

    private func header(_ session: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: DSSpace.s) {
            Text(session.date.fr(.dateTime.weekday(.wide).day().month(.wide))).ds(.footnote)
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
                if session.isDone { DoneMark() }
            }
            Text(headerDetail(session)).ds(.footnote)
            DSHairline().padding(.top, DSSpace.s)
        }
    }

    private func headerDetail(_ session: TrainingSession) -> String {
        var parts = [session.kind.sport.label]
        if session.status == .modified { parts.append("modifiée") }
        if session.isDone { parts.append("faite") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Endurance

    private func enduranceSection(_ session: TrainingSession, _ workout: EnduranceWorkout) -> some View {
        VStack(alignment: .leading, spacing: DSSpace.m) {
            DSWorkoutProfile(workout: workout, isKey: session.kind.role == .key)

            VStack(alignment: .leading, spacing: 0) {
                DSHairline()
                ForEach(Array(workout.items.enumerated()), id: \.offset) { _, item in
                    itemView(item, isKey: session.kind.role == .key)
                }
            }

            if let notes = workout.notes {
                Text(notes).ds(.footnote)
            }

            exportBlock(session, workout)
        }
    }

    @ViewBuilder
    private func itemView(_ item: WorkoutItem, isKey: Bool) -> some View {
        switch item {
        case .step(let step):
            stepRow(step, isKey: isKey)
        case .repeatBlock(let count, let steps):
            VStack(alignment: .leading, spacing: 0) {
                Text("\(count) fois")
                    .ds(.caption)
                    .padding(.top, DSSpace.s)
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    stepRow(step, isKey: isKey)
                }
            }
        }
    }

    private func stepRow(_ step: WorkoutStep, isKey: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(step.intensity.label).ds(.body)
                Spacer()
                VStack(alignment: .trailing, spacing: DSSpace.xs) {
                    Text(describe(step.duration)).ds(.body)
                    Text(describe(step.target))
                        .font(DSFont.footnote)
                        .foregroundStyle(step.intensity == .active && isKey ? DSColor.accentText : DSColor.textSecondary)
                }
            }
            .padding(.vertical, DSSpace.m)
            DSHairline()
        }
    }

    /// Le fichier .fit est régénéré à chaque modification : la tâche se relance quand la révision change.
    private func exportBlock(_ session: TrainingSession, _ workout: EnduranceWorkout) -> some View {
        VStack(alignment: .leading, spacing: DSSpace.s) {
            if let url = fitURL {
                ShareLink(item: url) {
                    DSOutlineLabel(text: "Exporter le fichier .fit", icon: "square.and.arrow.up")
                }
            }
            Text("Fichier version v\(session.fitRevision + 1). Après une modification, renvoyez-le vers la montre.")
                .ds(.footnote)
        }
        .task(id: session.fitRevision) {
            fitURL = try? FitExport.writeTemporaryFile(session: session, workout: workout)
        }
    }

    // MARK: - Muscu

    private func strengthSection(_ workout: StrengthWorkout) -> some View {
        VStack(alignment: .leading, spacing: DSSpace.m) {
            Text(workout.warmup).ds(.footnote)

            VStack(alignment: .leading, spacing: 0) {
                DSHairline()
                ForEach(Array(workout.items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: DSSpace.xs) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.exercise.name).ds(.body)
                                Spacer()
                                Text("\(item.sets) × \(item.scheme.text)").ds(.footnote)
                            }
                            if let note = item.exercise.safetyNote {
                                Text(note)
                                    .font(DSFont.footnote)
                                    .foregroundStyle(DSColor.accentText)
                            }
                        }
                        .padding(.vertical, DSSpace.m)
                        DSHairline()
                    }
                }
            }

            DSBanner(text: "Pas de fichier montre pour la muscu : séance à suivre dans l’app.", icon: "info.circle")
        }
    }

    // MARK: - Actions

    private func actions(_ session: TrainingSession) -> some View {
        VStack(spacing: DSSpace.s) {
            Button(session.isDone ? "Remettre à faire" : "Marquer comme faite") {
                store.setDone(session.id, !session.isDone)
            }
            .buttonStyle(.dsPrimary)

            Button("Modifier la séance") { showModify = true }
                .buttonStyle(.dsSecondary)
            Button("Changer de sport") { showChangeSport = true }
                .buttonStyle(.dsSecondary)
            Button("Déplacer") { showMove = true }
                .buttonStyle(.dsSecondary)
            Button("Annuler la séance") { confirmCancel = true }
                .buttonStyle(.dsDestructive)
        }
        .confirmationDialog("Annuler cette séance ?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Annuler la séance", role: .destructive) { store.cancel(session.id) }
            Button("Garder", role: .cancel) {}
        }
    }
}
