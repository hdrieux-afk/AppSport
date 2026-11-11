// RootView.swift
// Aiguillage : chargement, puis onboarding si aucun plan n'existe, sinon les trois onglets.

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if !store.isLoaded {
                ProgressView()
            } else if store.weeks.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .onAppear {
            store.attach(context)
            if ProcessInfo.processInfo.arguments.contains("-demo") && store.weeks.isEmpty {
                store.createDemoPlan()
            }
        }
    }
}
