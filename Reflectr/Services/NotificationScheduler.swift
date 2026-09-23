//
//  NotificationScheduler.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import Foundation
import UserNotifications

/// Schedules the optional weekly "review your training" reminder.
enum NotificationScheduler {
    private static let weeklyReviewID = "reflectr.weeklyReview"

    static func updateWeeklyReview(enabled: Bool, settings: Settings) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklyReviewID])
        guard enabled else { return }

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Weekly training review"
        content.body = "Look back at this week — how did your sessions go, and what changed?"
        content.sound = .default

        var components = DateComponents()
        components.weekday = settings.reviewWeekday
        components.hour = settings.reviewHour

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklyReviewID, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
