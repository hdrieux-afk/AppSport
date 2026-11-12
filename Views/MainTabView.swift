// MainTabView.swift
// Les trois onglets de l'app. Chaque onglet a sa propre pile de navigation.
// Seul l'onglet sélectionné est en rouge ; les contrôles à l'intérieur des écrans restent à l'encre.
// L'onglet sélectionné est mémorisé sous la clé "selectedTab" (argument de lancement -selectedTab 1).

import SwiftUI

struct MainTabView: View {
    @AppStorage("selectedTab") private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { TodayView() }
                .tint(DSColor.textPrimary)
                .tabItem { Label("Aujourd’hui", systemImage: "figure.run") }
                .tag(0)
            NavigationStack { PlanView() }
                .tint(DSColor.textPrimary)
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(1)
            NavigationStack { ProfileView() }
                .tint(DSColor.textPrimary)
                .tabItem { Label("Profil", systemImage: "person") }
                .tag(2)
        }
        .tint(DSColor.accentText)
    }
}
