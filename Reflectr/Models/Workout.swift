//
//  Workout.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import Foundation
import SwiftData

/// A single training session — either planned for the future, or completed
/// (logged by hand or imported from Apple Health).
@Model
final class Workout {
    var id: UUID? = UUID()
    var date: Date = Date.now
    var title: String = ""
    /// Raw value of `WorkoutType`; stored as String so SwiftData/CloudKit stay happy.
    var typeRaw: String = WorkoutType.other.rawValue

    /// A planned session lives in the future until you complete it.
    var isPlanned: Bool = false
    var isCompleted: Bool = false

    /// Where the session came from: `manual`, `health`, or `planned`.
    var source: String = WorkoutSource.manual.rawValue

    // Metrics (from Apple Health, or entered by hand)
    var durationMinutes: Double?
    var distanceMeters: Double?
    var activeEnergyKcal: Double?
    var avgHeartRate: Double?

    // Planning
    var plannedFocus: String?
    var notes: String?

    /// HealthKit sample UUID (as a string) used to avoid importing the same workout twice.
    var healthUUID: String?

    /// The reflection you write after training. Deleted with the workout.
    @Relationship(deleteRule: .cascade, inverse: \Reflection.workout)
    var reflection: Reflection?

    /// Exercises, for strength sessions (e.g. imported from Strong). Empty for cardio.
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise]?

    /// "How do I feel" snapshots: before, during, right after, days later.
    @Relationship(deleteRule: .cascade, inverse: \FeelingCheckIn.workout)
    var checkIns: [FeelingCheckIn]?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        title: String = "",
        type: WorkoutType = .other,
        isPlanned: Bool = false,
        isCompleted: Bool = false,
        source: WorkoutSource = .manual,
        durationMinutes: Double? = nil,
        distanceMeters: Double? = nil,
        activeEnergyKcal: Double? = nil,
        avgHeartRate: Double? = nil,
        plannedFocus: String? = nil,
        notes: String? = nil,
        healthUUID: String? = nil,
        reflection: Reflection? = nil
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.typeRaw = type.rawValue
        self.isPlanned = isPlanned
        self.isCompleted = isCompleted
        self.source = source.rawValue
        self.durationMinutes = durationMinutes
        self.distanceMeters = distanceMeters
        self.activeEnergyKcal = activeEnergyKcal
        self.avgHeartRate = avgHeartRate
        self.plannedFocus = plannedFocus
        self.notes = notes
        self.healthUUID = healthUUID
        self.reflection = reflection
    }
}

// MARK: - Convenience

extension Workout {
    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var workoutSource: WorkoutSource {
        WorkoutSource(rawValue: source) ?? .manual
    }

    /// A completed session that still has no reflection written.
    var needsReflection: Bool {
        isCompleted && reflection == nil
    }

    /// Check-ins for a phase, oldest first.
    func checkIns(for phase: CheckInPhase) -> [FeelingCheckIn] {
        (checkIns ?? []).filter { $0.phase == phase }.sorted { $0.date < $1.date }
    }

    var orderedExercises: [Exercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    /// A strength session has logged exercises (e.g. imported from Strong).
    var isStrength: Bool {
        !(exercises ?? []).isEmpty
    }

    /// e.g. "8 exercises · 18 sets".
    var strengthSummary: String {
        let ex = exercises ?? []
        guard !ex.isEmpty else { return "" }
        let setCount = ex.reduce(0) { $0 + ($1.sets?.count ?? 0) }
        return "\(ex.count) exercise\(ex.count == 1 ? "" : "s") · \(setCount) set\(setCount == 1 ? "" : "s")"
    }

    var distanceKm: Double? {
        guard let distanceMeters, distanceMeters > 0 else { return nil }
        return distanceMeters / 1000
    }

    /// Short one-line metric summary, e.g. "42 min · 8.1 km · 410 kcal".
    var metricSummary: String {
        var parts: [String] = []
        if let d = durationMinutes, d > 0 {
            parts.append("\(Int(d.rounded())) min")
        }
        if let km = distanceKm {
            parts.append(String(format: "%.1f km", km))
        }
        if let kcal = activeEnergyKcal, kcal > 0 {
            parts.append("\(Int(kcal.rounded())) kcal")
        }
        if let hr = avgHeartRate, hr > 0 {
            parts.append("\(Int(hr.rounded())) bpm")
        }
        return parts.joined(separator: " · ")
    }
}

enum WorkoutSource: String, Codable {
    case manual
    case health
    case planned
    case imported
}
