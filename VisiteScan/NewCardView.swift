//
//  NewCardView.swift
//  VisiteScan
//
//  Skandeer → lees → wysig → stoor.
//  Geraamte (Stap 1). Die skandeerdeel kom by Stap 2.
//

import SwiftUI
import SwiftData

struct NewCardView: View {

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Logo-kopskrif
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.rectangle")
                                .font(.system(size: 48))
                                .foregroundStyle(.blue)
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
                    ContentUnavailableView(
                        "Skandeer kom nog",
                        systemImage: "camera.viewfinder",
                        description: Text("Kamera, skandeerder, galery en lêers word by Stap 2 bygevoeg.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Nuwe kaartjie")
        }
    }
}

#Preview {
    NewCardView()
        .modelContainer(for: BusinessCard.self, inMemory: true)
}
