//
//  BriefingView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//
//  A pre-training briefing: recent sessions and what you told yourself to
//  "keep in mind" and "try next time" — grouped by session so it's in your
//  head before you train, not buried in history.

import SwiftUI
import SwiftData

struct BriefingView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    /// How many recent completed sessions to scan for notes.
    private let lookbackCount = 30
    /// Cap the number of session cards shown.
    private let sessionLimit = 10

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.briefingPath) {
            ScrollView {
                VStack(spacing: 20) {
                    // Oldest first, like the calendar: past sessions above, what's next below.
                    if sessions.isEmpty {
                        emptyState
                    } else {
                        ForEach(sessions.reversed()) { sessionCard($0) }
                    }

                    if let next = nextPlanned {
                        upNextCard(next)
                    }
                }
                .padding()
            }
            .defaultScrollAnchor(.bottom)
            .scrollContentBackground(.hidden)
            .background(BackgroundGradient())
            .navigationTitle("Briefing")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
        }
    }

    // MARK: - Up next

    private func upNextCard(_ workout: Workout) -> some View {
        NavigationLink(value: workout) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(workout.type.tint.opacity(0.18)).frame(width: 46, height: 46)
                    Image(systemName: workout.type.systemImage).foregroundStyle(workout.type.tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("UP NEXT").font(.caption2.bold()).foregroundStyle(.secondary)
                    Text(workout.title.isEmpty ? workout.type.label : workout.title)
                        .font(.headline)
                    Text(workout.date, format: .dateTime.weekday(.wide).day().month())
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session card

    private func sessionCard(_ session: SessionBrief) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: session.workout) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(session.workout.type.tint.opacity(0.18)).frame(width: 40, height: 40)
                        Image(systemName: session.workout.type.systemImage)
                            .foregroundStyle(session.workout.type.tint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sessionTitle(session.workout)).font(.headline)
                        Text(session.workout.date, format: .dateTime.weekday(.wide).day().month())
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Workout-level notes.
            ForEach(session.workoutNotes) { noteRow($0) }

            // Per-exercise notes.
            ForEach(session.exercises) { brief in
                VStack(alignment: .leading, spacing: 6) {
                    NavigationLink(value: brief.exercise) {
                        HStack(spacing: 4) {
                            Text(brief.exercise.name)
                                .font(.subheadline.weight(.medium))
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    ForEach(brief.notes) { noteRow($0) }
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func noteRow(_ note: BriefNote) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: note.kind.icon)
                .font(.caption)
                .foregroundStyle(note.kind.tint)
                .frame(width: 18)
            (
                Text("\(note.kind.label): ").font(.caption.weight(.semibold)).foregroundColor(note.kind.tint)
                + Text(note.text).font(.callout).foregroundColor(.primary)
            )
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            Text("Nothing to brief yet")
                .font(.headline)
            Text("After a session, note what to keep in mind and what to try next time. Your recent sessions will show up here before your next workout.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
    }

    // MARK: - Data

    private var recentCompleted: [Workout] {
        Array(workouts.lazy.filter { $0.isCompleted }.prefix(lookbackCount))
    }

    private var nextPlanned: Workout? {
        let now = Date.now
        return workouts
            .filter { $0.isPlanned && !$0.isCompleted && $0.date >= now.startOfDay }
            .min { $0.date < $1.date }
    }

    /// Recent sessions that carry at least one note, grouped session by session.
    private var sessions: [SessionBrief] {
        var result: [SessionBrief] = []
        for workout in recentCompleted {
            var workoutNotes: [BriefNote] = []
            if let r = workout.reflection {
                if let t = r.tryNextTime, !t.isEmpty { workoutNotes.append(BriefNote(kind: .tryNext, text: t)) }
                if let k = r.keepInMind, !k.isEmpty { workoutNotes.append(BriefNote(kind: .keep, text: k)) }
            }

            var exercises: [ExerciseBrief] = []
            for exercise in workout.orderedExercises {
                var notes: [BriefNote] = []
                if let t = exercise.tryNextTime, !t.isEmpty { notes.append(BriefNote(kind: .tryNext, text: t)) }
                if let l = exercise.lookFor, !l.isEmpty { notes.append(BriefNote(kind: .keep, text: l)) }
                if !notes.isEmpty {
                    exercises.append(ExerciseBrief(exercise: exercise, notes: notes))
                }
            }

            if !workoutNotes.isEmpty || !exercises.isEmpty {
                result.append(SessionBrief(workout: workout, workoutNotes: workoutNotes, exercises: exercises))
            }
            if result.count >= sessionLimit { break }
        }
        return result
    }

    private func sessionTitle(_ workout: Workout) -> String {
        workout.title.isEmpty ? workout.type.label : workout.title
    }
}

// MARK: - Briefing models

private struct SessionBrief: Identifiable {
    let workout: Workout
    let workoutNotes: [BriefNote]
    let exercises: [ExerciseBrief]
    var id: PersistentIdentifier { workout.persistentModelID }
}

private struct ExerciseBrief: Identifiable {
    let exercise: Exercise
    let notes: [BriefNote]
    var id: PersistentIdentifier { exercise.persistentModelID }
}

private struct BriefNote: Identifiable {
    let id = UUID()
    let kind: BriefKind
    let text: String
}

private enum BriefKind {
    case tryNext
    case keep

    var label: String {
        switch self {
        case .tryNext: return "Try next time"
        case .keep: return "Keep in mind"
        }
    }

    var icon: String {
        switch self {
        case .tryNext: return "flask"
        case .keep: return "eye"
        }
    }

    var tint: Color {
        switch self {
        case .tryNext: return .accentColor
        case .keep: return .blue
        }
    }
}
