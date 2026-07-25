//
//  CardListView.swift
//  VisiteScan
//
//  Geskiedenis van geskandeerde kaartjies.
//  Geraamte (Stap 1). Soek, uitvoer en duplikaatopsporing kom by Stap 6 en 7.
//

import SwiftUI
import SwiftData

struct CardListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessCard.dateScanned, order: .reverse) private var cards: [BusinessCard]

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    ContentUnavailableView(
                        "Nog geen kaartjies",
                        systemImage: "person.crop.rectangle",
                        description: Text("Skandeer jou eerste visitekaartjie op die Nuut-oortjie.")
                    )
                } else {
                    List {
                        ForEach(cards) { card in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.displayName)
                                    .font(.headline)
                                if !card.subtitle.isEmpty {
                                    Text(card.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteCards)
                    }
                }
            }
            .navigationTitle("Kaarte")
            .toolbar {
                if !cards.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(cards[index])
            }
        }
    }
}

#Preview {
    CardListView()
        .modelContainer(for: BusinessCard.self, inMemory: true)
}
