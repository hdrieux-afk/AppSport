// SessionSheets.swift
// Les deux fenêtres qui s'ouvrent depuis une séance : Modifier, et Changer de sport.
// Chacune appelle une action du store ; le fichier .fit est régénéré par l'écran de détail.

import SwiftUI

struct ModifySessionSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession
    @State private var duration: Int
    @State private var level: Level

    init(session: TrainingSession) {
        self.session = session
        _duration = State(initialValue: session.durationMin)
        _level = State(initialValue: session.level)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Durée") {
                    Stepper("\(duration) min", value: $duration, in: session.kind.durationRange, step: 5)
                }
                Section("Intensité") {
                    Picker("Intensité", selection: $level) {
                        Text("Facile").tag(Level.easy)
                        Text("Prévu").tag(Level.planned)
                        Text("Intense").tag(Level.hard)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Text("Les étapes, les cibles et le fichier .fit sont recalculés automatiquement.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        store.modify(session.id, durationMin: duration, level: level)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct ChangeSportSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession

    var body: some View {
        NavigationStack {
            List {
                ForEach(SessionKind.choices(venue: store.constraints?.strengthVenue ?? .home), id: \.title) { kind in
                    Button {
                        store.changeSport(session.id, to: kind)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            SessionIcon(kind: kind)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title)
                                Text("Durée équivalente : \(equivalentDuration(for: kind)) min")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            if kind == session.kind {
                                Text("Actuel").font(.footnote).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .disabled(kind == session.kind)
                }
            }
            .navigationTitle("Changer de sport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    /// On applique le changement sur une copie, pour afficher la durée calculée par le domaine
    /// sans modifier la vraie séance.
    private func equivalentDuration(for kind: SessionKind) -> Int {
        var copy = session
        copy.changeSport(to: kind)
        return copy.durationMin
    }
}
