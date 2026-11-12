// AppSportApp.swift
// Point d'entrée de l'app : crée le store, la base SwiftData, et applique la charte (clair et sombre selon l'iPhone).

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
                .tint(DSColor.textPrimary)
        }
        .modelContainer(for: PlanEntity.self)
    }
}
