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
                // Les écrans actuels (charte Trail) sont clairs ; le guide de style suit le réglage de l'iPhone.
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-styleguide") ? nil : .light)
                .tint(Theme.terracotta)
        }
        .modelContainer(for: PlanEntity.self)
    }
}
