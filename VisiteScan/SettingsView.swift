//
//  SettingsView.swift
//  VisiteScan
//

import SwiftUI

struct SettingsView: View {

    // MARK: iCloud-sinkronisering (Stap 9)
    // Haal die kommentaar weg wanneer CloudKit aangeskakel word:
    // @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: iCloud-afdeling — Stap 9
                // Section {
                //     Toggle("Sinkroniseer met iCloud", isOn: $iCloudSyncEnabled)
                // } header: {
                //     Text("Sinkronisering")
                // } footer: {
                //     Text("Kaartjies word tussen jou toestelle gesinkroniseer via jou eie iCloud-rekening.")
                //         .font(.caption)
                // }

                Section {
                    HStack {
                        Text("VisiteScan")
                            .fontWeight(.bold)
                        Spacer()
                        Text("Weergawe \(appVersion)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    HStack {
                        Text("Berging")
                        Spacer()
                        Text("Net plaaslik")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("Oor")
                }
            }
            .navigationTitle("Instellings")
        }
    }
}

#Preview {
    SettingsView()
}
