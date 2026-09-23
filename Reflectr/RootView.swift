//
//  RootView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [Settings]
    @State private var router = AppRouter()
    @State private var health = HealthKitManager()

    var body: some View {
        ContentView()
            .environment(router)
            .environment(health)
            .environment(settings)
            .task { await autoImportIfEnabled() }
    }

    /// The single Settings row, created lazily if CloudKit hasn't synced one yet.
    private var settings: Settings {
        if let existing = settingsList.first { return existing }
        let created = Settings()
        context.insert(created)
        return created
    }

    private func autoImportIfEnabled() async {
        guard settings.healthImportEnabled else { return }
        let since = settings.lastHealthSync ?? Date.now.addingDays(-90)
        let existing = existingHealthUUIDs()
        let count = await health.importWorkouts(
            into: context, since: since, existingHealthUUIDs: existing
        )
        if count >= 0 {
            settings.lastHealthSync = .now
            try? context.save()
        }
    }

    private func existingHealthUUIDs() -> Set<String> {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.healthUUID != nil }
        )
        let workouts = (try? context.fetch(descriptor)) ?? []
        return Set(workouts.compactMap { $0.healthUUID })
    }
}
