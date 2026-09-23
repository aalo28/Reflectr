//
//  ItemsContainer.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import Foundation
import SwiftData

actor ItemsContainer {
    @MainActor
    static func create(shouldSeed: inout Bool) -> ModelContainer {
        let schema = Schema([Workout.self, Reflection.self, Exercise.self, ExerciseSet.self, Settings.self])
        let config = ModelConfiguration(
            "Reflectr",
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .private("iCloud.com.aalohan.Reflectr")
        )
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            if shouldSeed {
                // A single Settings row backs the app's preferences.
                container.mainContext.insert(Settings())
                shouldSeed = false
                try container.mainContext.save()
            }
            return container
        } catch {
            fatalError("Couldn't create ModelContainer: " + error.localizedDescription)
        }
    }
}
