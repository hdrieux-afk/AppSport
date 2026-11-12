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
                if let id = demoSessionID {
                    NavigationStack { SessionDetailView(sessionID: id) }
                } else {
                    MainTabView()
                }
            } else if store.draft != nil {
                PlanProposalView()
            } else {
                OnboardingView()
            }
        }
        // onAppear se répète à chaque changement d'écran : attach() est sans effet après le premier appel.
        .onAppear { store.attach(context) }
    }

    /// Pour les captures de la CI : l'argument -showDetail run, bike ou strength ouvre directement une séance.
    private var demoSessionID: UUID? {
        guard let which = UserDefaults.standard.string(forKey: "showDetail") else { return nil }
        let all = store.weeks.flatMap { $0.sessions }
        switch which {
        case "strength": return all.first { $0.kind.sport == .strength }?.id
        case "bike": return all.first { $0.kind.sport == .bike }?.id
        default: return all.first { $0.kind.role == .key }?.id
        }
    }
}
