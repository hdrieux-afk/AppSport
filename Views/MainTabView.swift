// MainTabView.swift
// Les trois onglets de l'app. Chaque onglet a sa propre pile de navigation.
// L'onglet sélectionné est mémorisé sous la clé "selectedTab" : l'intégration continue
// s'en sert (argument de lancement -selectedTab 1) pour photographier chaque écran.

import SwiftUI

struct MainTabView: View {
    @AppStorage("selectedTab") private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { TodayView() }
                .tabItem { Label("Aujourd’hui", systemImage: "figure.run") }
                .tag(0)
            NavigationStack { PlanView() }
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(1)
            NavigationStack { ProfileView() }
                .tabItem { Label("Profil", systemImage: "person") }
                .tag(2)
        }
    }
}
