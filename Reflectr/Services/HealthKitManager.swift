//
//  HealthKitManager.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//
//  Reads completed workouts from Apple Health. Garmin, Apple Watch and most
//  other trackers write their sessions into Apple Health, so importing from
//  HealthKit surfaces them all in one place.

import Foundation
import SwiftData
import HealthKit

@Observable
@MainActor
final class HealthKitManager {
    private let store = HKHealthStore()

    /// Whether HealthKit is usable on this device at all.
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Result of the most recent import, for surfacing in the UI.
    var lastImportCount: Int = 0
    var isImporting: Bool = false
    var lastError: String?

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        types.insert(HKQuantityType(.heartRate))
        types.insert(HKQuantityType(.activeEnergyBurned))
        return types
    }

    /// Ask the user for read access to workouts and related metrics.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Import completed workouts since `since` into the model context,
    /// skipping any whose HealthKit UUID we already have.
    @discardableResult
    func importWorkouts(
        into context: ModelContext,
        since: Date,
        existingHealthUUIDs: Set<String>
    ) async -> Int {
        guard isAvailable else { return 0 }
        isImporting = true
        defer { isImporting = false }

        let workouts = await fetchWorkouts(since: since)
        var inserted = 0

        for hk in workouts {
            let uuid = hk.uuid.uuidString
            if existingHealthUUIDs.contains(uuid) { continue }

            let type = WorkoutType(hkActivityType: hk.workoutActivityType)
            let avgHR = await averageHeartRate(for: hk)

            let workout = Workout(
                date: hk.startDate,
                title: type.label,
                type: type,
                isPlanned: false,
                isCompleted: true,
                source: .health,
                durationMinutes: hk.duration / 60,
                distanceMeters: hk.totalDistanceMeters,
                activeEnergyKcal: hk.totalEnergyKilocalories,
                avgHeartRate: avgHR,
                healthUUID: uuid
            )
            context.insert(workout)
            inserted += 1
        }

        if inserted > 0 {
            try? context.save()
        }
        lastImportCount = inserted
        return inserted
    }

    // MARK: - Queries

    private func fetchWorkouts(since: Date) async -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    private func averageHeartRate(for workout: HKWorkout) async -> Double? {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate, end: workout.endDate, options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                let bpm = stats?.averageQuantity()?
                    .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }
}

// MARK: - HealthKit bridging helpers

private extension HKWorkout {
    var totalDistanceMeters: Double? {
        // `totalDistance` is deprecated but still returns aggregated distance
        // across activity types, which is exactly what we want for a summary.
        totalDistance?.doubleValue(for: .meter())
    }

    var totalEnergyKilocalories: Double? {
        totalEnergyBurned?.doubleValue(for: .kilocalorie())
    }
}

extension WorkoutType {
    init(hkActivityType: HKWorkoutActivityType) {
        switch hkActivityType {
        case .running: self = .run
        case .cycling: self = .ride
        case .swimming: self = .swim
        case .traditionalStrengthTraining, .functionalStrengthTraining: self = .strength
        case .highIntensityIntervalTraining: self = .hiit
        case .flexibility, .cooldown, .preparationAndRecovery: self = .mobility
        case .yoga, .mindAndBody, .pilates: self = .yoga
        case .walking: self = .walk
        case .hiking: self = .hike
        case .soccer, .basketball, .tennis, .americanFootball, .volleyball,
             .hockey, .badminton, .tableTennis, .racquetball, .squash,
             .handball, .cricket, .rugby:
            self = .sport
        default: self = .other
        }
    }
}
