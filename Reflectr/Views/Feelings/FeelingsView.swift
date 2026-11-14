//
//  FeelingsView.swift
//  Reflectr
//
//  Every completed workout as a row: title on top, then four columns —
//  Before · During · Right after · +1 day — so you can scan how you respond
//  workout for workout.
//

import SwiftUI
import SwiftData

struct FeelingsView: View {
    @Query(
        filter: #Predicate<Workout> { $0.isCompleted },
        sort: \Workout.date,
        order: .reverse
    ) private var workouts: [Workout]

    @State private var editing: (workout: Workout, target: CheckInTarget)?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                    Section {
                        if workouts.isEmpty {
                            ContentUnavailableView(
                                "No workouts yet",
                                systemImage: "waveform.path.ecg",
                                description: Text("Completed workouts show up here so you can compare how you felt.")
                            )
                            .padding(.top, 40)
                        }
                        ForEach(workouts) { workout in
                            FeelingsRow(workout: workout) { target in
                                editing = (workout, target)
                            }
                        }
                    } header: {
                        columnHeader
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .scrollContentBackground(.hidden)
            .background(BackgroundGradient())
            .navigationTitle("Feelings")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .sheet(isPresented: Binding(
                get: { editing != nil },
                set: { if !$0 { editing = nil } }
            )) {
                if let editing {
                    CheckInEditorView(workout: editing.workout, target: editing.target)
                }
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 6) {
            ForEach(CheckInPhase.allCases) { phase in
                VStack(spacing: 2) {
                    Image(systemName: phase.systemImage)
                    Text(phase.columnTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.bar, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Row

private struct FeelingsRow: View {
    let workout: Workout
    let onSelect: (CheckInTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: workout) {
                HStack(spacing: 8) {
                    Image(systemName: workout.type.systemImage)
                        .foregroundStyle(workout.type.tint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(workout.title.isEmpty ? workout.type.label : workout.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(workout.date, format: .dateTime.weekday(.abbreviated).day().month())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(alignment: .top, spacing: 6) {
                ForEach(CheckInPhase.allCases) { phase in
                    cell(for: phase)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func cell(for phase: CheckInPhase) -> some View {
        // For "+1 day" use the first later check-in.
        let entry = workout.checkIns(for: phase).first
        Button {
            onSelect(entry.map { .existing($0) } ?? .new(phase))
        } label: {
            FeelingCell(checkIn: entry)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(phase.columnTitle): \(entry?.note ?? "not logged")")
    }
}

private struct FeelingCell: View {
    let checkIn: FeelingCheckIn?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let c = checkIn {
                HStack(spacing: 4) {
                    if let f = c.feeling { score("face.smiling", f) }
                    if let e = c.energy { score("bolt", e) }
                }
                if let s = c.soreness { score("bandage", s) }
                if let rel = c.relativeLabel, rel != "1 day after" {
                    Text(rel).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                }
                if let note = c.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(checkIn == nil ? Color.gray.opacity(0.08) : Color.accentColor.opacity(0.10))
        )
        .contentShape(Rectangle())
    }

    private func score(_ icon: String, _ value: Int) -> some View {
        Label("\(value)", systemImage: icon)
            .labelStyle(.titleAndIcon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.accentColor)
    }
}

extension CheckInPhase {
    /// Short header used in the Feelings grid.
    var columnTitle: String {
        switch self {
        case .before: "Before"
        case .during: "During"
        case .after: "After"
        case .later: "+1 day"
        }
    }
}
