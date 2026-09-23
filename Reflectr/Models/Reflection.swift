//
//  Reflection.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import Foundation
import SwiftData

/// What you write after a training session: how it felt, what wasn't optimal,
/// what to keep in mind, and what to try next time.
@Model
final class Reflection {
    var id: UUID? = UUID()
    var createdDate: Date = Date.now
    var workout: Workout?

    /// Overall how it felt, 1 (bad) … 5 (great).
    var feeling: Int?
    /// Energy going in / during, 1 (drained) … 5 (fresh).
    var energy: Int?
    /// Perceived effort (RPE), 1 (easy) … 10 (max).
    var rpe: Int?

    var whatWentWell: String?
    var whatWasntOptimal: String?
    var keepInMind: String?
    var tryNextTime: String?

    /// Quick, reusable labels e.g. "poor sleep", "great flow", "sore".
    var tags: [String]?

    init(
        id: UUID = UUID(),
        createdDate: Date = .now,
        workout: Workout? = nil,
        feeling: Int? = nil,
        energy: Int? = nil,
        rpe: Int? = nil,
        whatWentWell: String? = nil,
        whatWasntOptimal: String? = nil,
        keepInMind: String? = nil,
        tryNextTime: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.createdDate = createdDate
        self.workout = workout
        self.feeling = feeling
        self.energy = energy
        self.rpe = rpe
        self.whatWentWell = whatWentWell
        self.whatWasntOptimal = whatWasntOptimal
        self.keepInMind = keepInMind
        self.tryNextTime = tryNextTime
        self.tags = tags
    }
}

extension Reflection {
    /// True when nothing has been filled in yet.
    var isEmpty: Bool {
        feeling == nil && energy == nil && rpe == nil
            && (whatWentWell ?? "").isEmpty
            && (whatWasntOptimal ?? "").isEmpty
            && (keepInMind ?? "").isEmpty
            && (tryNextTime ?? "").isEmpty
            && (tags ?? []).isEmpty
    }
}
