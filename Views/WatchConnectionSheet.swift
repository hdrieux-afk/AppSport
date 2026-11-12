// WatchConnectionSheet.swift
// Connexion à intervals.icu pour envoyer les séances vers la montre sans câble.
// intervals.icu transmet ensuite les séances à Garmin Connect, qui les envoie à la montre.

import SwiftUI

struct WatchConnectionSheet: View {
    @Environment(AppStore.self) private var store

    @State private var athleteID = ""
    @State private var apiKey = ""

    var body: some View {
        DSSheetFrame(title: "Envoi vers la montre") {
            VStack(alignment: .leading, spacing: DSSpace.l) {
                steps

                if store.watchConnected {
                    connectedBlock
                } else {
                    connectionForm
                }

                if store.watchBusy {
                    ProgressView()
                }
                if let message = store.watchMessage {
                    Text(message).ds(.footnote)
                }
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: DSSpace.s) {
            DSSectionLabel(text: "À faire une seule fois")
            Text("1. Créez un compte gratuit sur intervals.icu.").ds(.body)
            Text("2. Dans ses réglages, connectez Garmin et cochez « Upload planned workouts ».").ds(.body)
            Text("3. Dans ses réglages de course, renseignez la même FC max que dans l’app.").ds(.body)
            Text("4. Copiez ici votre identifiant (de la forme i123456, avec le « i ») et votre clé d’API (Settings, Developer Settings).").ds(.body)
            DSHairline().padding(.top, DSSpace.s)
        }
    }

    private var connectionForm: some View {
        VStack(alignment: .leading, spacing: DSSpace.s) {
            DSFieldRow(label: "Identifiant") {
                TextField("i123456", text: $athleteID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .font(DSFont.headline)
                    .frame(width: 160)
            }
            DSFieldRow(label: "Clé d’API") {
                SecureField("clé", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .font(DSFont.headline)
                    .frame(width: 160)
            }
            Button("Tester et enregistrer") {
                Task { await store.connectWatch(athleteID: athleteID, apiKey: apiKey) }
            }
            .buttonStyle(.dsPrimary)
            .disabled(athleteID.isEmpty || apiKey.isEmpty || store.watchBusy)
            .opacity(athleteID.isEmpty || apiKey.isEmpty ? 0.4 : 1)
            Text("La clé est conservée dans le Trousseau de l’iPhone, jamais dans l’app.").ds(.footnote)
        }
    }

    private var connectedBlock: some View {
        VStack(alignment: .leading, spacing: DSSpace.s) {
            DSLabeledRow(label: "Compte", value: store.watchAthleteID)
            Button("Envoyer les 14 prochains jours") {
                Task { await store.sendUpcomingToWatch(days: 14) }
            }
            .buttonStyle(.dsPrimary)
            .disabled(store.watchBusy)
            Button("Se déconnecter") { store.disconnectWatch() }
                .buttonStyle(.dsDestructive)
            Text("intervals.icu ne transmet à Garmin Connect que les séances des 7 prochains jours environ ; la montre les reçoit à sa prochaine synchronisation.")
                .ds(.footnote)
        }
    }
}
