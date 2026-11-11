// AppSportApp.swift
// Point d'entrée de l'app : crée le store, la base SwiftData, et applique la charte Trail.

import SwiftUI
import SwiftData

@main
struct AppSportApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .preferredColorScheme(.light)        // la charte Trail n'a pas encore de mode sombre
                .tint(Theme.terracotta)
        }
        .modelContainer(for: PlanEntity.self)
    }
}
