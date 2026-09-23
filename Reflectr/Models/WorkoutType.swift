//
//  WorkoutType.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI

/// The kind of training session, used for icons, colour, and grouping.
enum WorkoutType: String, CaseIterable, Identifiable, Codable {
    case run
    case ride
    case swim
    case strength
    case hiit
    case mobility
    case yoga
    case walk
    case hike
    case sport
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .run: return "Run"
        case .ride: return "Ride"
        case .swim: return "Swim"
        case .strength: return "Strength"
        case .hiit: return "HIIT"
        case .mobility: return "Mobility"
        case .yoga: return "Yoga"
        case .walk: return "Walk"
        case .hike: return "Hike"
        case .sport: return "Sport"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .run: return "figure.run"
        case .ride: return "figure.outdoor.cycle"
        case .swim: return "figure.pool.swim"
        case .strength: return "dumbbell.fill"
        case .hiit: return "figure.highintensity.intervaltraining"
        case .mobility: return "figure.cooldown"
        case .yoga: return "figure.yoga"
        case .walk: return "figure.walk"
        case .hike: return "figure.hiking"
        case .sport: return "sportscourt.fill"
        case .other: return "figure.mixed.cardio"
        }
    }

    var tint: Color {
        switch self {
        case .run: return .orange
        case .ride: return .green
        case .swim: return .blue
        case .strength: return .purple
        case .hiit: return .red
        case .mobility: return .teal
        case .yoga: return .mint
        case .walk: return .cyan
        case .hike: return .brown
        case .sport: return .indigo
        case .other: return .gray
        }
    }
}
