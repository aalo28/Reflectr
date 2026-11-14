//
//  FeelingCheckIn.swift
//  Reflectr
//
//  A quick "how do I feel right now?" snapshot tied to a workout, taken at a
//  specific moment: before, during, right after, or some days later.
//

import Foundation
import SwiftData

enum CheckInPhase: String, CaseIterable, Codable, Identifiable {
    case before
    case during
    case after
    case later

    var id: String { rawValue }

    var label: String {
        switch self {
        case .before: "Before"
        case .during: "During"
        case .after: "Right after"
        case .later: "Days later"
        }
    }

    var systemImage: String {
        switch self {
        case .before: "sunrise"
        case .during: "figure.run"
        case .after: "flag.checkered"
        case .later: "calendar.badge.clock"
        }
    }

    var prompt: String {
        switch self {
        case .before: "How do you feel going in?"
        case .during: "How is it feeling right now?"
        case .after: "How do you feel now that it's done?"
        case .later: "Looking back — how is your body doing?"
        }
    }

    /// Soreness is mostly meaningful once the session is over.
    var tracksSoreness: Bool { self == .after || self == .later }

    /// "Days later" can be logged more than once (e.g. day 1 and day 3).
    var allowsMultiple: Bool { self == .later }
}

@Model
final class FeelingCheckIn {
    var id: UUID? = UUID()
    var date: Date = Date.now
    var workout: Workout?

    /// Raw value of `CheckInPhase`; stored as String for SwiftData/CloudKit.
    var phaseRaw: String = CheckInPhase.before.rawValue

    /// Mood / overall feeling, 1 (bad) … 5 (great).
    var feeling: Int?
    /// Energy, 1 (drained) … 5 (fresh).
    var energy: Int?
    /// Muscle soreness, 1 (none) … 5 (very sore).
    var soreness: Int?

    var note: String?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        workout: Workout? = nil,
        phase: CheckInPhase,
        feeling: Int? = nil,
        energy: Int? = nil,
        soreness: Int? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.workout = workout
        self.phaseRaw = phase.rawValue
        self.feeling = feeling
        self.energy = energy
        self.soreness = soreness
        self.note = note
    }
}

extension FeelingCheckIn {
    var phase: CheckInPhase {
        get { CheckInPhase(rawValue: phaseRaw) ?? .before }
        set { phaseRaw = newValue.rawValue }
    }

    /// e.g. "2 days after" for a later check-in, relative to the workout date.
    var relativeLabel: String? {
        guard phase == .later, let workoutDate = workout?.date else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: workoutDate), to: cal.startOfDay(for: date)).day ?? 0
        switch days {
        case ..<1: return "Same day"
        case 1: return "1 day after"
        default: return "\(days) days after"
        }
    }
}
