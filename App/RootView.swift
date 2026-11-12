// RootView.swift
// Aiguillage : chargement, puis onboarding, proposition de plan, ou les trois onglets.

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var context

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-styleguide") {
            StyleGuideView()
        } else {
            content
        }
    }

    private var content: some View {
        Group {
            if !store.isLoaded {
                ProgressView()
            } else if !store.weeks.isEmpty {
                MainTabView()
            } else if store.draft != nil {
                PlanProposalView()
            } else {
                OnboardingView()
            }
        }
        // onAppear se répète à chaque changement d'écran : attach() est sans effet après le premier appel.
        .onAppear { store.attach(context) }
    }
}
