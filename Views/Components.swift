// Components.swift
// Petites briques d'interface réutilisées par plusieurs écrans.

import SwiftUI
import Charts

/// Pastille d'icône : pleine pour une séance clé, claire pour une séance de soutien.
struct SessionIcon: View {
    let kind: SessionKind

    var body: some View {
        let sport = kind.sport
        let solid = kind.role == .key
        Image(systemName: sport.symbol)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(solid ? Color.white : sport.color)
            .frame(width: 34, height: 34)
            .background(solid ? sport.color : sport.tint)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// Ligne de séance : icône, titre, durée, état.
struct SessionRow: View {
    let session: TrainingSession

    var body: some View {
        HStack(spacing: 12) {
            SessionIcon(kind: session.kind)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.kind.title)
                    .strikethrough(session.status == .cancelled)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if session.isDone {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sage)
            }
        }
        .contentShape(Rectangle())
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

/// Profil visuel d'une séance d'endurance : une barre par étape, largeur proportionnelle à la durée.
struct WorkoutProfileBar: View {
    let workout: EnduranceWorkout

    var body: some View {
        let segs = workout.segments
        let total = max(segs.reduce(0) { $0 + $1.seconds }, 1)
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(segs.enumerated()), id: \.offset) { _, seg in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(workout.sport.color.opacity(seg.intensity.opacity))
                        .frame(width: max(2, (geo.size.width - CGFloat(segs.count) * 2) * CGFloat(seg.seconds / total)),
                               height: seg.intensity == .active ? 44 : 18)
                }
            }
            .frame(height: geo.size.height, alignment: .bottom)
        }
        .frame(height: 48)
    }
}

/// Jauge de faisabilité d'un objectif : prudent, réaliste, ambitieux.
struct FeasibilityBadge: View {
    let goal: RaceGoal
    let vmaKmh: Double

    var body: some View {
        if let result = assessFeasibility(goal, vmaKmh: vmaKmh) {
            let range = goal.distance.vmaFractionRange
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle().fill(result.level.color).frame(width: 10, height: 10)
                    Text(result.level.label).fontWeight(.semibold)
                    Spacer()
                    Text("\(Int((result.vmaFraction * 100).rounded())) % de la VMA")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                if let pace = goal.targetPaceMps {
                    Text("Allure visée : \(formatPace(pace)) /km")
                        .font(.footnote)
                }
                Text("Sur \(goal.distance.label), on court en général entre \(Int((range.lowerBound * 100).rounded())) % et \(Int((range.upperBound * 100).rounded())) % de sa VMA.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

/// Volume total de chaque semaine, en minutes : montre la montée en charge, les décharges et l'affûtage.
struct WeeklyVolumeChart: View {
    let weeks: [PlannedWeek]

    var body: some View {
        Chart(weeks) { week in
            BarMark(x: .value("Semaine", "S\(week.index + 1)"),
                    y: .value("Minutes", week.sessions.reduce(0) { $0 + $1.durationMin }))
                .foregroundStyle(Theme.terracotta)
        }
        .frame(height: 140)
    }
}
