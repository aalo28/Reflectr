//
//  Exercise.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import Foundation
import SwiftData

/// A single exercise within a strength workout (e.g. "Pull Up"), with its sets
/// and your per-exercise reflection.
@Model
final class Exercise {
    var id: UUID? = UUID()
    var name: String = ""
    /// Position within the workout, to keep the logged order.
    var order: Int = 0

    /// Notes captured in the original log (the "Notes:" line from Strong).
    var logNotes: String?

    /// Reflection you add afterwards.
    var tryNextTime: String?
    var lookFor: String?

    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet]?

    init(
        id: UUID = UUID(),
        name: String = "",
        order: Int = 0,
        logNotes: String? = nil,
        tryNextTime: String? = nil,
        lookFor: String? = nil,
        workout: Workout? = nil,
        sets: [ExerciseSet]? = nil
    ) {
        self.id = id
        self.name = name
        self.order = order
        self.logNotes = logNotes
        self.tryNextTime = tryNextTime
        self.lookFor = lookFor
        self.workout = workout
        self.sets = sets
    }
}

extension Exercise {
    var orderedSets: [ExerciseSet] {
        (sets ?? []).sorted { $0.order < $1.order }
    }

    var hasReflection: Bool {
        !(tryNextTime ?? "").isEmpty || !(lookFor ?? "").isEmpty
    }

    /// The heaviest working set, for a quick at-a-glance headline.
    var topSet: ExerciseSet? {
        orderedSets.max { lhs, rhs in
            (lhs.weightKg ?? 0, lhs.reps ?? 0) < (rhs.weightKg ?? 0, rhs.reps ?? 0)
        }
    }

    /// One-line set summary, e.g. "16 kg × 6, 14 kg × 5" or "8, 8 reps".
    var setSummary: String {
        let sets = orderedSets
        guard !sets.isEmpty else { return "No sets" }
        let weighted = sets.contains { ($0.weightKg ?? 0) > 0 }
        if weighted {
            return sets.map { $0.shortLabel }.joined(separator: ", ")
        } else {
            let reps = sets.compactMap { $0.reps }.map(String.init).joined(separator: ", ")
            return reps.isEmpty ? "\(sets.count) sets" : "\(reps) reps"
        }
    }
}
