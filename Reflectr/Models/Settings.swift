//
//  Settings.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import Foundation
import SwiftData

@Model
final class Settings {
    var id: UUID = UUID()
    /// Automatically pull completed workouts from Apple Health.
    var healthImportEnabled: Bool = false
    /// Timestamp of the last successful Health import (for incremental syncs).
    var lastHealthSync: Date?
    /// Send a weekly nudge to review the week's training.
    var weeklyReviewReminder: Bool = false
    /// Weekday for the weekly review reminder (1 = Sunday … 7 = Saturday).
    var reviewWeekday: Int = 1
    var reviewHour: Int = 18

    init(
        id: UUID = UUID(),
        healthImportEnabled: Bool = false,
        lastHealthSync: Date? = nil,
        weeklyReviewReminder: Bool = false,
        reviewWeekday: Int = 1,
        reviewHour: Int = 18
    ) {
        self.id = id
        self.healthImportEnabled = healthImportEnabled
        self.lastHealthSync = lastHealthSync
        self.weeklyReviewReminder = weeklyReviewReminder
        self.reviewWeekday = reviewWeekday
        self.reviewHour = reviewHour
    }
}
