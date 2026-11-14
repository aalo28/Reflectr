//
//  AppRouter.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import Foundation
import SwiftUI

enum MyTabs: Int {
    case briefing
    case calendar
    case plan
    case feelings
    case review
}

/// App-wide navigation state: which tab is showing, and each tab's stack.
@Observable
final class AppRouter {
    var selectedTab: MyTabs = .briefing
    var briefingPath: [Workout] = []
    var calendarPath: [Workout] = []
    var planPath: [Workout] = []

    /// Switch to the calendar tab and push a workout's detail view.
    func openWorkout(_ workout: Workout) {
        calendarPath = [workout]
        selectedTab = .calendar
    }
}
