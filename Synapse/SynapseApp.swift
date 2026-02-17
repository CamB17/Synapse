//
//  SynapseApp.swift
//  Synapse
//
//  Created by Home on 2/17/26.
//

import SwiftUI
import CoreData

@main
struct SynapseApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
