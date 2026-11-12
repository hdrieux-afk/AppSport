// DSLayout.swift
// Composants de mise en page de la charte : titre d'écran, ligne de séance, compteur, champ,
// faisabilité, profil de séance et graphique du volume. Uniquement des tokens, jamais de valeur en dur.

import SwiftUI

/// Titre d'écran en serif, avec un sous-titre discret au-dessus.
struct DSScreenHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpace.xs) {
            if let subtitle = subtitle {
                Text(subtitle).ds(.footnote)
            }
            Text(title).ds(.display)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DSSpace.l)
    }
}

/// Ligne de séance : pictogramme du sport, titre, détails, point rouge si séance clé, repère si faite.
struct DSSessionRow: View {
    let session: TrainingSession

    var body: some View {
        HStack(spacing: DSSpace.m) {
            SportGlyph(sport: session.kind.sport)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.kind.title)
                    .strikethrough(session.status == .cancelled)
                    .ds(.headline)
                Text(subtitle).ds(.footnote)
            }
            Spacer(minLength: DSSpace.s)
            if isKey { KeyMarker() }
            if session.isDone { DoneMark() }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var isKey: Bool {
        session.kind.role == .key && session.status != .cancelled && !session.isDone
    }

    private var subtitle: String {
        if session.status == .cancelled { return "Annulée" }
        var parts = ["\(session.durationMin) min"]
        if session.kind.role == .key { parts.append("séance clé") }
        if session.status == .modified { parts.append("modifiée") }
        if session.isDone { parts.append("faite") }
        return parts.joined(separator: ", ")
    }
}

/// Compteur : libellé à gauche, boutons moins et plus autour de la valeur, filet dessous.
struct DSStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var unit: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DSSpace.m) {
                Text(label).ds(.body)
                Spacer()
                stepButton(icon: "minus", name: "Diminuer") {
                    value = max(range.lowerBound, value - step)
                }
                Text("\(value)\(unit)")
                    .ds(.headline)
                    .frame(minWidth: 64)
                stepButton(icon: "plus", name: "Augmenter") {
                    value = min(range.upperBound, value + step)
                }
            }
            .padding(.vertical, DSSpace.s)
            DSHairline()
        }
    }

    private func stepButton(icon: String, name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(DSColor.textPrimary)
                .frame(width: 36, height: 36)
                .overlay(RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(DSColor.textPrimary, lineWidth: DSStroke.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }
}

/// Ligne de formulaire : libellé à gauche, contrôle libre à droite, filet dessous.
struct DSFieldRow<Content: View>: View {
    let label: String
    private let content: () -> Content

    init(label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).ds(.body)
                Spacer()
                content()
            }
            .padding(.vertical, DSSpace.m)
            DSHairline()
        }
    }
}

/// Bouton secondaire dont on ne contrôle pas le style de bouton (par exemple un ShareLink).
struct DSOutlineLabel: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: DSSpace.s) {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(DSFont.body)
        .foregroundStyle(DSColor.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 48)
        .overlay(RoundedRectangle(cornerRadius: DSRadius.small)
            .stroke(DSColor.textPrimary, lineWidth: DSStroke.hairline))
    }
}

/// Faisabilité d'un objectif : un mot, une échelle à 4 crans, le rouge seulement pour "très ambitieux".
struct DSFeasibility: View {
    let goal: RaceGoal
    let vmaKmh: Double

    var body: some View {
        if let result = assessFeasibility(goal, vmaKmh: vmaKmh) {
            let range = goal.distance.vmaFractionRange
            VStack(alignment: .leading, spacing: DSSpace.s) {
                HStack {
                    Text(result.level.label).ds(.headline)
                    Spacer()
                    Text("\(Int((result.vmaFraction * 100).rounded())) % de la VMA").ds(.footnote)
                }
                HStack(spacing: DSSpace.xs) {
                    ForEach(0..<4, id: \.self) { index in
                        Rectangle()
                            .fill(index <= result.level.rank ? barColor(for: result.level) : DSColor.separator)
                            .frame(height: 3)
                    }
                }
                if let pace = goal.targetPaceMps {
                    Text("Allure visée : \(formatPace(pace)) /km").ds(.footnote)
                }
                Text("Sur \(goal.distance.label), on court en général entre \(Int((range.lowerBound * 100).rounded())) % et \(Int((range.upperBound * 100).rounded())) % de sa VMA.")
                    .ds(.footnote)
            }
            .padding(.vertical, DSSpace.m)
        }
    }

    private func barColor(for level: Feasibility) -> Color {
        level == .veryAmbitious ? DSColor.accent : DSColor.textPrimary
    }
}

/// Profil d'une séance d'endurance : une barre par étape, largeur proportionnelle à la durée.
/// L'effort est en rouge pour une séance clé, en encre sinon ; le reste est en gris de filet.
struct DSWorkoutProfile: View {
    let workout: EnduranceWorkout
    var isKey: Bool = false

    var body: some View {
        let segs = workout.segments
        let total = max(segs.reduce(0) { $0 + $1.seconds }, 1)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in
                    Rectangle()
                        .fill(seg.intensity == .active ? (isKey ? DSColor.accent : DSColor.textPrimary) : DSColor.separator)
                        .frame(width: max(2, (geo.size.width - CGFloat(segs.count) * 2) * CGFloat(seg.seconds / total)),
                               height: seg.intensity == .active ? 48 : 18)
                }
            }
            .frame(height: geo.size.height, alignment: .bottom)
        }
        .frame(height: 52)
    }
}

/// Volume total de chaque semaine, en minutes. La semaine de pic est en rouge.
struct DSVolumeChart: View {
    let weeks: [PlannedWeek]

    var body: some View {
        let values = weeks.map { week in week.sessions.reduce(0) { $0 + $1.durationMin } }
        let top = max(values.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: DSSpace.xs) {
                    Text("\(value)").ds(.caption)
                    Rectangle()
                        .fill(value == top ? DSColor.accent : DSColor.textPrimary)
                        .frame(height: max(4, 100 * CGFloat(value) / CGFloat(top)))
                    Text("S\(index + 1)").ds(.caption)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 150, alignment: .bottom)
    }
}

/// Cadre commun des fenêtres : titre en serif, bouton Fermer, fond de la charte.
struct DSSheetFrame<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    private let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpace.l) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).ds(.title)
                    Spacer()
                    Button("Fermer") { dismiss() }
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.textPrimary)
                }
                content()
            }
            .padding(DSSpace.l)
        }
        .background(DSColor.background.ignoresSafeArea())
    }
}
