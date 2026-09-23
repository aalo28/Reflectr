//
//  WorkoutDetailView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Workout.date, order: .reverse) private var allWorkouts: [Workout]

    let workout: Workout

    @State private var showReflection = false
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if workout.isStrength {
                    exercisesSection
                }
                if !workout.metricSummary.isEmpty {
                    metricsCard
                }
                if !workout.isStrength {
                    priorAdviceCard
                }
                if workout.isPlanned && !workout.isCompleted {
                    plannedActions
                } else {
                    reflectionSection
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(BackgroundGradient())
        .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
        .navigationTitle(workout.type.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { delete() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showReflection) {
            ReflectionEditorView(workout: workout)
        }
        .sheet(isPresented: $showEdit) {
            AddWorkoutView(editing: workout)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(workout.type.tint.opacity(0.18)).frame(width: 56, height: 56)
                Image(systemName: workout.type.systemImage)
                    .font(.title2)
                    .foregroundStyle(workout.type.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title.isEmpty ? workout.type.label : workout.title)
                    .font(.title3.bold())
                Text(workout.date, format: .dateTime.weekday().day().month().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if workout.workoutSource == .health {
                    Label("From Apple Health", systemImage: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                }
            }
            Spacer()
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Exercises", systemImage: "dumbbell")
                    .font(.subheadline.bold())
                Spacer()
                Text(workout.strengthSummary)
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(workout.orderedExercises) { exercise in
                NavigationLink(value: exercise) {
                    ExerciseRow(exercise: exercise)
                }
                .buttonStyle(.plain)
                if exercise.id != workout.orderedExercises.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var metricsCard: some View {
        HStack {
            if let d = workout.durationMinutes, d > 0 {
                metric("\(Int(d.rounded()))", "min", "clock")
            }
            if let km = workout.distanceKm {
                metric(String(format: "%.1f", km), "km", "point.topleft.down.to.point.bottomright.curvepath")
            }
            if let kcal = workout.activeEnergyKcal, kcal > 0 {
                metric("\(Int(kcal.rounded()))", "kcal", "flame")
            }
            if let hr = workout.avgHeartRate, hr > 0 {
                metric("\(Int(hr.rounded()))", "bpm", "heart")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ value: String, _ unit: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.callout).foregroundStyle(.secondary)
            Text(value).font(.headline)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Surfaces "what to try next time" and "keep in mind" notes from your last
    /// few sessions of the same type — so advice from past-you shows up before
    /// you train, not buried in history.
    @ViewBuilder
    private var priorAdviceCard: some View {
        let advice = priorAdvice
        if !advice.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("From past \(workout.type.label.lowercased()) sessions", systemImage: "lightbulb")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                ForEach(advice, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(line).font(.callout)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var plannedActions: some View {
        VStack(spacing: 12) {
            if let focus = workout.plannedFocus, !focus.isEmpty {
                infoBlock("Focus", focus)
            }
            if let notes = workout.notes, !notes.isEmpty {
                infoBlock("Notes", notes)
            }
            Button {
                markCompleted()
            } label: {
                Label("Mark as completed", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    @ViewBuilder
    private var reflectionSection: some View {
        if let reflection = workout.reflection, !reflection.isEmpty {
            ReflectionSummaryView(reflection: reflection)
            Button {
                showReflection = true
            } label: {
                Label("Edit reflection", systemImage: "pencil").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        } else {
            VStack(spacing: 12) {
                if let notes = workout.notes, !notes.isEmpty {
                    infoBlock("Notes", notes)
                }
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)
                    Text("How did it go?")
                        .font(.headline)
                    Text("Log how you felt, what wasn't optimal, and what to try next time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        showReflection = true
                    } label: {
                        Label("Add reflection", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func infoBlock(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.caption2).foregroundStyle(.secondary)
            Text(text).font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Logic

    private var priorAdvice: [String] {
        let sameType: [Workout] = allWorkouts.filter { past in
            past.type == workout.type && past.date < workout.date
        }
        var lines: [String] = []
        for past in sameType.prefix(6) {
            guard let r = past.reflection else { continue }
            var line: String? = nil
            if let t = r.tryNextTime, !t.isEmpty {
                line = t
            } else if let k = r.keepInMind, !k.isEmpty {
                line = k
            }
            if let line, !lines.contains(line) {
                lines.append(line)
            }
        }
        return lines
    }

    private func markCompleted() {
        workout.isCompleted = true
        workout.isPlanned = false
        try? context.save()
        showReflection = true
    }

    private func delete() {
        context.delete(workout)
        try? context.save()
        dismiss()
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.body.weight(.medium))
                Text(exercise.setSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let notes = exercise.logNotes, !notes.isEmpty {
                    Label(notes, systemImage: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if exercise.hasReflection {
                Image(systemName: "flask.fill").foregroundStyle(Color.accentColor)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
