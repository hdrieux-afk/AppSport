// Tokens.swift
// Base de design : papier blanc, encre noire, un seul rouge.
// Règle d'or : aucun écran n'écrit une couleur, une taille de police, un espacement ou un rayon en dur.
// Tout passe par DSColor, DSText, DSSpace, DSRadius et DSStroke.

import SwiftUI
import UIKit

// MARK: - Couleurs (elles suivent le mode clair ou sombre de l'iPhone)

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// Une couleur qui change toute seule selon le mode d'affichage, sans fichier de ressources.
private func adaptive(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
    })
}

enum DSColor {
    /// Fond d'écran : le papier en clair, l'encre en sombre.
    static let background = adaptive(light: 0xFAF8F4, dark: 0x141414)
    /// Fond des groupes de formulaire, très proche du fond.
    static let surface = adaptive(light: 0xF2EFE9, dark: 0x1E1E1E)
    /// Filet fin : sépare les lignes à la place des cartes. Décoratif, jamais porteur de sens seul.
    static let separator = adaptive(light: 0xD9D5CE, dark: 0x333333)

    static let textPrimary = adaptive(light: 0x141414, dark: 0xFAF8F4)      // 17:1 sur le fond
    static let textSecondary = adaptive(light: 0x595959, dark: 0x8C8C8C)    // 6,6:1 en clair, 5,5:1 en sombre

    /// Le rouge, pour les formes : repère de séance faite, point de séance clé, barres d'effort, anneau de progression.
    static let accent = adaptive(light: 0xC8102E, dark: 0xC8102E)
    /// Le rouge quand il porte du texte ou un trait fin : plus clair en sombre pour rester lisible (5,5:1).
    static let accentText = adaptive(light: 0xC8102E, dark: 0xEF5B5B)
    /// Texte posé sur un fond rouge.
    static let onAccent = Color.white
}

// MARK: - Espacements, rayons, traits

enum DSSpace {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    /// Le grand vide entre un titre et son contenu.
    static let xxxl: CGFloat = 48
}

enum DSRadius {
    /// Boutons, repères, champs : presque droits.
    static let small: CGFloat = 2
}

enum DSStroke {
    static let hairline: CGFloat = 1
}

// MARK: - Textes : 7 rôles

enum DSFont {
    /// Serif classique fourni par iOS (Hiragino Mincho, ses lettres latines) ; à défaut, le serif du système.
    private static let serifName: String? = {
        for name in ["HiraMinProN-W3", "HiraMinProN-W6"] where UIFont(name: name, size: 12) != nil {
            return name
        }
        return nil
    }()

    private static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        if let name = serifName { return .custom(name, size: size, relativeTo: style) }
        return .system(size: size, design: .serif)
    }

    static let hero = serif(56, relativeTo: .largeTitle)
    static let display = serif(34, relativeTo: .largeTitle)
    static let title = serif(24, relativeTo: .title2)
    static let headline = Font.system(.headline).weight(.medium)
    static let body = Font.system(.body)
    static let footnote = Font.system(.footnote)
    static let caption = Font.system(.caption)
}

enum DSText {
    case hero, display, title, headline, body, footnote, caption

    var font: Font {
        switch self {
        case .hero: return DSFont.hero
        case .display: return DSFont.display
        case .title: return DSFont.title
        case .headline: return DSFont.headline
        case .body: return DSFont.body
        case .footnote: return DSFont.footnote
        case .caption: return DSFont.caption
        }
    }

    var color: Color {
        switch self {
        case .footnote, .caption: return DSColor.textSecondary
        default: return DSColor.textPrimary
        }
    }
}

extension View {
    /// Applique un rôle de texte : police et couleur. Exemple : Text("55 min").ds(.footnote)
    func ds(_ role: DSText) -> some View {
        font(role.font).foregroundStyle(role.color)
    }
}

// MARK: - Pictogrammes des sports

extension Sport {
    /// Un pictogramme fin par sport : c'est lui, et non la couleur, qui distingue course, vélo et muscu.
    var glyph: String {
        switch self {
        case .run: return "figure.run"
        case .bike: return "bicycle"
        case .strength: return "dumbbell"
        }
    }
}
