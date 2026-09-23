//
//  ExerciseSet.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import Foundation
import SwiftData

/// One set of an exercise: reps, and optionally the weight used.
@Model
final class ExerciseSet {
    var id: UUID? = UUID()
    var order: Int = 0
    var reps: Int?
    var weightKg: Double?
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        order: Int = 0,
        reps: Int? = nil,
        weightKg: Double? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.order = order
        self.reps = reps
        self.weightKg = weightKg
        self.exercise = exercise
    }
}

extension ExerciseSet {
    /// e.g. "16 kg × 6", "6 reps", "bodyweight".
    var shortLabel: String {
        if let weightKg, weightKg > 0 {
            let weight = weightKg.formatted(.number.precision(.fractionLength(0...1)))
            if let reps { return "\(weight) kg × \(reps)" }
            return "\(weight) kg"
        }
        if let reps { return "\(reps) reps" }
        return "—"
    }
}
