//
//  SettingsView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var health
    @Query private var settingsList: [Settings]

    @State private var syncMessage: String?

    private var settings: Settings {
        if let existing = settingsList.first { return existing }
        let created = Settings()
        context.insert(created)
        return created
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: healthBinding) {
                        Label("Import from Apple Health", systemImage: "heart.fill")
                    }
                    Button {
                        Task { await syncNow() }
                    } label: {
                        HStack {
                            Label("Sync now", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if health.isImporting { ProgressView() }
                        }
                    }
                    .disabled(health.isImporting || !health.isAvailable)
                    if let syncMessage {
                        Text(syncMessage).font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Garmin, Apple Watch and most trackers write workouts to Apple Health, so importing brings them all into your calendar automatically.")
                }

                Section {
                    Toggle(isOn: reminderBinding) {
                        Label("Weekly review reminder", systemImage: "bell.badge")
                    }
                } footer: {
                    Text("A gentle nudge each week to look back at how your training went.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text("Reflectr — plan your training, then reflect on how it actually went.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Bindings

    private var healthBinding: Binding<Bool> {
        Binding(
            get: { settings.healthImportEnabled },
            set: { newValue in
                settings.healthImportEnabled = newValue
                try? context.save()
                if newValue { Task { await enableHealth() } }
            }
        )
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { settings.weeklyReviewReminder },
            set: { newValue in
                settings.weeklyReviewReminder = newValue
                try? context.save()
                Task { await NotificationScheduler.updateWeeklyReview(enabled: newValue, settings: settings) }
            }
        )
    }

    // MARK: - Actions

    private func enableHealth() async {
        let ok = await health.requestAuthorization()
        if ok { await syncNow() }
    }

    private func syncNow() async {
        let since = settings.lastHealthSync ?? Date.now.addingDays(-90)
        let existing = existingHealthUUIDs()
        let count = await health.importWorkouts(into: context, since: since, existingHealthUUIDs: existing)
        settings.lastHealthSync = .now
        try? context.save()
        syncMessage = count > 0 ? "Imported \(count) new workout\(count == 1 ? "" : "s")." : "You're up to date."
    }

    private func existingHealthUUIDs() -> Set<String> {
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.healthUUID != nil })
        let workouts = (try? context.fetch(descriptor)) ?? []
        return Set(workouts.compactMap { $0.healthUUID })
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return v
    }
}
