// Theme.swift
// Charte graphique "Trail" : couleurs, titres, et un style de carte réutilisable.

import SwiftUI

extension Color {
    /// Couleur depuis un code hexadécimal, par exemple Color(hex: 0xC8643B).
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

enum Theme {
    static let cream = Color(hex: 0xF3EDE2)        // fond des écrans
    static let card = Color(hex: 0xFAF6EE)         // fond des cartes
    static let forest = Color(hex: 0x2B3A2F)       // texte fort, muscu
    static let terracotta = Color(hex: 0xC8643B)   // accent, course
    static let sage = Color(hex: 0x8FA68A)
    static let sand = Color(hex: 0xD9CDB5)         // séparateurs
    static let muted = Color(hex: 0x6B7A6E)        // texte secondaire
    static let lake = Color(hex: 0x4F7CA3)         // vélo

    /// Titres : serif système en attendant d'embarquer la police Fraunces.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
}

// Une couleur par sport, partout dans l'app.
extension Sport {
    var color: Color {
        switch self {
        case .run: return Theme.terracotta
        case .bike: return Theme.lake
        case .strength: return Theme.forest
        }
    }

    /// Version claire, utilisée pour les séances de soutien.
    var tint: Color {
        switch self {
        case .run: return Color(hex: 0xF0D9CC)
        case .bike: return Color(hex: 0xD5E3EE)
        case .strength: return Color(hex: 0xD5DDD6)
        }
    }

    var label: String {
        switch self {
        case .run: return "Course"
        case .bike: return "Vélo"
        case .strength: return "Muscu"
        }
    }

    var symbol: String {
        switch self {
        case .run: return "figure.run"
        case .bike: return "bicycle"
        case .strength: return "dumbbell.fill"
        }
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.sand.opacity(0.6), lineWidth: 0.5))
    }
}

extension View {
    /// Applique le style carte : fond crème clair, coins arrondis, fin contour.
    func card() -> some View { modifier(CardStyle()) }
}
