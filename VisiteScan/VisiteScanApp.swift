//
//  VisiteScanApp.swift
//  VisiteScan
//
//  Created by Erich Lutz on 2026/07/25.
//

import SwiftUI
import SwiftData

@main
struct VisiteScanApp: App {

    let container: ModelContainer

    init() {
        let schema = Schema([BusinessCard.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Skema-konflik tydens ontwikkeling — vee die ou stoor uit en begin vars.
            // (Selfde herstel as FuelScan. Sodra die model gevestig is en daar
            // regte data in is, moet dit 'n behoorlike migrasie word.)
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                        in: .userDomainMask).first {
                for file in ["default.store", "default.store-shm", "default.store-wal"] {
                    try? FileManager.default.removeItem(at: appSupport.appending(path: file))
                }
            }
            do {
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("SwiftData kon nie laai nie: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
