// DSComponents.swift
// Composants de base, tous construits uniquement avec les tokens de Tokens.swift.

import SwiftUI

// MARK: - Boutons

struct DSButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.body)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(RoundedRectangle(cornerRadius: DSRadius.small).stroke(border, lineWidth: DSStroke.hairline))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return DSColor.background
        case .secondary: return DSColor.textPrimary
        case .destructive: return DSColor.accentText
        }
    }

    private var background: Color {
        kind == .primary ? DSColor.textPrimary : Color.clear
    }

    private var border: Color {
        switch kind {
        case .primary: return Color.clear
        case .secondary: return DSColor.textPrimary
        case .destructive: return DSColor.accentText
        }
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    /// Action principale : encre pleine (noire en clair, blanche en sombre).
    static var dsPrimary: DSButtonStyle { DSButtonStyle(kind: .primary) }
    /// Action secondaire : simple contour.
    static var dsSecondary: DSButtonStyle { DSButtonStyle(kind: .secondary) }
    /// Action destructive : contour rouge.
    static var dsDestructive: DSButtonStyle { DSButtonStyle(kind: .destructive) }
}

// MARK: - Filets et lignes

struct DSHairline: View {
    var body: some View {
        Rectangle()
            .fill(DSColor.separator)
            .frame(height: DSStroke.hairline)
    }
}

/// Une ligne "libellé, valeur" séparée par un filet : remplace les cartes.
struct DSLabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).ds(.body)
                Spacer()
                Text(value).ds(.footnote)
            }
            .padding(.vertical, DSSpace.m)
            DSHairline()
        }
    }
}

/// Petit intitulé de section, discret.
struct DSSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .ds(.caption)
            .padding(.bottom, DSSpace.xs)
    }
}

/// Information importante : deux filets et une icône, sans fond coloré.
struct DSBanner: View {
    let text: String
    var icon: String = "exclamationmark.circle"

    var body: some View {
        VStack(spacing: 0) {
            DSHairline()
            HStack(alignment: .top, spacing: DSSpace.m) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(DSColor.textPrimary)
                Text(text)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textPrimary)
            }
            .padding(.vertical, DSSpace.m)
            DSHairline()
        }
    }
}

// MARK: - Pictogrammes et repères

/// Le pictogramme fin d'un sport.
struct SportGlyph: View {
    let sport: Sport
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: sport.glyph)
            .font(.system(size: size, weight: .light))
            .foregroundStyle(DSColor.textPrimary)
            .frame(width: size * 1.6, height: size * 1.6)
    }
}

/// Point rouge : marque une séance clé.
struct KeyMarker: View {
    var body: some View {
        Circle()
            .fill(DSColor.accent)
            .frame(width: 8, height: 8)
    }
}

/// Repère rouge à coche : marque une séance faite.
struct DoneMark: View {
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.6, weight: .bold))
            .foregroundStyle(DSColor.onAccent)
            .frame(width: size, height: size)
            .background(DSColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
    }
}

/// Anneau de progression de 0 à 1, par exemple la semaine 3 sur 9.
struct ProgressRing: View {
    let value: Double
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .stroke(DSColor.separator, lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(DSColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
