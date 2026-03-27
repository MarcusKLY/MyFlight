//
//  MyFlightApp.swift
//  MyFlight
//
//  Created by Kam Long Yin on 23/3/2026.
//

import SwiftUI
import SwiftData

@main
struct MyFlightApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Airport.self, Flight.self, TransitSegment.self)
            // Disabled auto-seeding - user can add flights manually
            // FlightSeedData.seedIfNeeded(in: modelContainer.mainContext)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
