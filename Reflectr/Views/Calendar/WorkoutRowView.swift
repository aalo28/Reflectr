//
//  WorkoutRowView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI

struct WorkoutRowView: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(workout.type.tint.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: workout.type.systemImage)
                    .foregroundStyle(workout.type.tint)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.title.isEmpty ? workout.type.label : workout.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if workout.isPlanned && !workout.isCompleted {
                        Text("Planned")
                    } else {
                        Text(workout.date, format: .dateTime.hour().minute())
                    }
                    if !workout.metricSummary.isEmpty {
                        Text("·")
                        Text(workout.metricSummary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            statusBadge
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if workout.isPlanned && !workout.isCompleted {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(.secondary)
        } else if workout.reflection != nil {
            Image(systemName: "text.bubble.fill")
                .foregroundStyle(Color.accentColor)
        } else if workout.needsReflection {
            Image(systemName: "exclamationmark.bubble")
                .foregroundStyle(.orange)
        }
    }
}
