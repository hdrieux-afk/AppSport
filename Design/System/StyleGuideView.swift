// StyleGuideView.swift
// Le guide de style vivant : il affiche les vrais tokens et composants de l'app.
// Lancé avec l'argument -styleguide, il est photographié par l'intégration continue en clair et en sombre.
// Le sélecteur du haut est mémorisé sous la clé "guidePage" (argument -guidePage 0, 1 ou 2).

import SwiftUI

struct StyleGuideView: View {
    @AppStorage("guidePage") private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Page", selection: $page) {
                Text("Couleurs").tag(0)
                Text("Textes").tag(1)
                Text("Composants").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(DSSpace.l)

            ScrollView {
                VStack(alignment: .leading, spacing: DSSpace.xl) {
                    switch page {
                    case 0: colorsPage
                    case 1: typographyPage
                    default: componentsPage
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DSSpace.l)
                .padding(.bottom, DSSpace.xxl)
            }
        }
        .background(DSColor.background.ignoresSafeArea())
        .tint(DSColor.textPrimary)
    }

    // MARK: - Page 1 : couleurs

    private static let swatches: [(name: String, usage: String, color: Color)] = [
        ("background", "Fond d'écran : papier ou encre", DSColor.background),
        ("surface", "Groupes de formulaire", DSColor.surface),
        ("separator", "Filets fins", DSColor.separator),
        ("textPrimary", "Texte principal, bouton principal", DSColor.textPrimary),
        ("textSecondary", "Détails, légendes", DSColor.textSecondary),
        ("accent", "Rouge des formes : repère, point, barres", DSColor.accent),
        ("accentText", "Rouge du texte et des traits fins", DSColor.accentText)
    ]

    @ViewBuilder
    private var colorsPage: some View {
        Text("Couleurs").ds(.display)
        Text("Un seul accent, le rouge. Le reste est encre et papier.").ds(.footnote)
        ForEach(Self.swatches, id: \.name) { swatch in
            HStack(spacing: DSSpace.m) {
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .fill(swatch.color)
                    .frame(width: 56, height: 40)
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.small)
                        .stroke(DSColor.separator, lineWidth: DSStroke.hairline))
                VStack(alignment: .leading, spacing: 2) {
                    Text(swatch.name).ds(.body)
                    Text(swatch.usage).ds(.footnote)
                }
            }
        }
    }

    // MARK: - Page 2 : textes

    private static let roles: [(name: String, sample: String, role: DSText)] = [
        ("hero, serif 56", "45:00", .hero),
        ("display, serif 34", "Aujourd’hui", .display),
        ("title, serif 24", "Seuil 3 × 8", .title),
        ("headline, sans 17 moyen", "Fractionné long", .headline),
        ("body, sans 17", "Séance du jour, 55 min", .body),
        ("footnote, sans 13", "55 min, séance clé", .footnote),
        ("caption, sans 11", "Semaine 4, décharge", .caption)
    ]

    @ViewBuilder
    private var typographyPage: some View {
        Text("Textes").ds(.display)
        Text("Sept rôles. Les tailles suivent le réglage de taille de texte de l'iPhone.").ds(.footnote)
        ForEach(Self.roles, id: \.name) { item in
            VStack(alignment: .leading, spacing: DSSpace.xs) {
                Text(item.name).ds(.caption)
                Text(item.sample).ds(item.role)
                DSHairline().padding(.top, DSSpace.xs)
            }
        }
    }

    // MARK: - Page 3 : composants

    private static let spaces: [(name: String, value: CGFloat)] = [
        ("xs", DSSpace.xs), ("s", DSSpace.s), ("m", DSSpace.m),
        ("l", DSSpace.l), ("xl", DSSpace.xl), ("xxl", DSSpace.xxl)
    ]

    @ViewBuilder
    private var componentsPage: some View {
        Text("Composants").ds(.display)

        VStack(spacing: DSSpace.s) {
            Button("Valider le plan") {}.buttonStyle(.dsPrimary)
            Button("Modifier la séance") {}.buttonStyle(.dsSecondary)
            Button("Annuler la séance") {}.buttonStyle(.dsDestructive)
        }

        VStack(alignment: .leading, spacing: 0) {
            DSSectionLabel(text: "Séances")
            HStack(spacing: DSSpace.m) {
                SportGlyph(sport: .run)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fractionné long").ds(.headline)
                    Text("55 min, séance clé").ds(.footnote)
                }
                Spacer()
                KeyMarker()
            }
            .padding(.vertical, DSSpace.m)
            DSHairline()
            HStack(spacing: DSSpace.m) {
                SportGlyph(sport: .bike)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sortie vélo").ds(.headline)
                    Text("60 min").ds(.footnote)
                }
                Spacer()
            }
            .padding(.vertical, DSSpace.m)
            DSHairline()
            HStack(spacing: DSSpace.m) {
                SportGlyph(sport: .strength)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Muscu jambes, maison").ds(.headline)
                    Text("45 min, faite").ds(.footnote)
                }
                Spacer()
                DoneMark()
            }
            .padding(.vertical, DSSpace.m)
            DSHairline()
        }

        HStack(spacing: DSSpace.xl) {
            ProgressRing(value: 0.33)
            VStack(alignment: .leading, spacing: 2) {
                Text("Semaine 3 sur 9").ds(.headline)
                Text("Phase de développement").ds(.footnote)
            }
        }

        VStack(alignment: .leading, spacing: 0) {
            DSLabeledRow(label: "Durée du plan", value: "9 semaines")
            DSLabeledRow(label: "Séances par semaine", value: "5")
        }

        DSBanner(text: "Attention : deux séances dures d'affilée")

        VStack(alignment: .leading, spacing: DSSpace.xs) {
            DSSectionLabel(text: "Espacements")
            ForEach(Self.spaces, id: \.name) { space in
                HStack(spacing: DSSpace.m) {
                    Text("\(space.name), \(Int(space.value))").ds(.footnote)
                        .frame(width: 64, alignment: .leading)
                    Rectangle().fill(DSColor.accent).frame(width: space.value * 4, height: DSSpace.xs)
                }
            }
        }
    }
}
