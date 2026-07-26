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

                // Die logo het op die skandeerskerm plek gemors; hier hoort dit.
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            if let logo = UIImage(named: "AppLogo") {
                                Image(uiImage: logo)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 72, height: 72)
                                    .cornerRadius(16)
                            } else {
                                Image(systemName: "person.crop.rectangle")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.blue)
                            }
                            Text("VisiteScan")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

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
