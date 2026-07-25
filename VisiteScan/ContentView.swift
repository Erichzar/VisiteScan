//
//  ContentView.swift
//  VisiteScan
//
//  Created by Erich Lutz on 2026/07/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {

            NewCardView()
                .tabItem {
                    Label("Nuut", systemImage: "plus.circle.fill")
                }

            CardListView()
                .tabItem {
                    Label("Kaarte", systemImage: "list.bullet")
                }

            SettingsView()
                .tabItem {
                    Label("Instellings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BusinessCard.self, inMemory: true)
}
