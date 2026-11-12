// SessionSheets.swift
// Les trois fenêtres qui s'ouvrent depuis une séance : Modifier, Changer de sport, Déplacer.
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
        DSSheetFrame(title: "Modifier la séance") {
            VStack(alignment: .leading, spacing: DSSpace.l) {
                DSStepperRow(label: "Durée", value: $duration, range: session.kind.durationRange, step: 5, unit: " min")

                VStack(alignment: .leading, spacing: DSSpace.s) {
                    DSSectionLabel(text: "Intensité")
                    Picker("Intensité", selection: $level) {
                        Text("Facile").tag(Level.easy)
                        Text("Prévu").tag(Level.planned)
                        Text("Intense").tag(Level.hard)
                    }
                    .pickerStyle(.segmented)
                }

                Text("Les étapes, les cibles et le fichier .fit sont recalculés automatiquement.")
                    .ds(.footnote)

                Button("Enregistrer") {
                    store.modify(session.id, durationMin: duration, level: level)
                    dismiss()
                }
                .buttonStyle(.dsPrimary)
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
        DSSheetFrame(title: "Changer de sport") {
            VStack(alignment: .leading, spacing: 0) {
                DSHairline()
                ForEach(SessionKind.choices(venue: store.constraints?.strengthVenue ?? .home), id: \.title) { kind in
                    Button {
                        store.changeSport(session.id, to: kind)
                        dismiss()
                    } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: DSSpace.m) {
                                SportGlyph(sport: kind.sport)
                                VStack(alignment: .leading, spacing: DSSpace.xs) {
                                    Text(kind.title).ds(.headline)
                                    Text("Durée équivalente : \(equivalentDuration(for: kind)) min").ds(.footnote)
                                }
                                Spacer()
                                if kind == session.kind {
                                    Text("Actuel").ds(.caption)
                                }
                            }
                            .padding(.vertical, DSSpace.m)
                            DSHairline()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(kind == session.kind)
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

/// Choix du jour d'arrivée parmi les 7 jours de la même semaine, avec un avertissement non bloquant.
struct MoveSessionSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let session: TrainingSession

    var body: some View {
        DSSheetFrame(title: "Déplacer la séance") {
            VStack(alignment: .leading, spacing: 0) {
                DSHairline()
                if let start = store.weekStart(of: session.id) {
                    ForEach(0..<7, id: \.self) { day in
                        dayRow(day: day, weekStart: start)
                    }
                }
            }
        }
    }

    private func dayRow(day: Int, weekStart: Date) -> some View {
        let date = Calendar.current.date(byAdding: .day, value: day, to: weekStart) ?? weekStart
        let isCurrent = Calendar.current.isDate(date, inSameDayAs: session.date)
        let issues = store.issuesAfterMoving(session.id, toDay: day)
        return Button {
            store.move(session.id, toDay: day)
            dismiss()
        } label: {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: DSSpace.xs) {
                    Text(date.fr(.dateTime.weekday(.wide).day().month(.wide))).ds(.headline)
                    if isCurrent {
                        Text("Jour actuel").ds(.footnote)
                    } else if !issues.isEmpty {
                        Text("Attention : " + issues.map { $0.message }.joined(separator: ", "))
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.accentText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DSSpace.m)
                DSHairline()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
    }
}
