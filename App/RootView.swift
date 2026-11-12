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
        .onAppear {
            store.attach(context)
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-resetPlan") { store.reset() }
            if args.contains("-demo") && store.weeks.isEmpty {
                store.createDemoPlan()
            } else if args.contains("-demoDraft") && store.weeks.isEmpty && store.draft == nil {
                store.createDemoDraft()
            }
        }
    }
}
