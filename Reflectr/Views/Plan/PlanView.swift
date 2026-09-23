//
//  PlanView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Query(sort: \Workout.date, order: .forward) private var workouts: [Workout]

    @State private var showAdd = false
    @State private var showImport = false

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.planPath) {
            List {
                if !upcoming.isEmpty {
                    Section("Upcoming") {
                        ForEach(upcoming) { workout in
                            NavigationLink(value: workout) {
                                PlanRow(workout: workout)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    complete(workout)
                                } label: {
                                    Label("Complete", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                        .onDelete { delete(upcoming, at: $0) }
                    }
                }

                if !needingReflection.isEmpty {
                    Section("Needs a reflection") {
                        ForEach(needingReflection) { workout in
                            NavigationLink(value: workout) {
                                WorkoutRowView(workout: workout)
                            }
                        }
                    }
                }

                if upcoming.isEmpty && needingReflection.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing planned", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("Plan your next sessions so you can reflect on them afterwards.")
                    } actions: {
                        Button("Plan a workout") { showAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BackgroundGradient())
            .navigationTitle("Plan")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showAdd = true } label: {
                            Label("New workout", systemImage: "square.and.pencil")
                        }
                        Button { showImport = true } label: {
                            Label("Import from Strong…", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddWorkoutView(defaultDate: Date.now.addingDays(1).startOfDay, startPlanned: true)
            }
            .sheet(isPresented: $showImport) {
                ImportWorkoutView()
            }
        }
    }

    private var upcoming: [Workout] {
        let today = Date.now.startOfDay
        return workouts.filter { $0.isPlanned && !$0.isCompleted && $0.date >= today }
    }

    private var needingReflection: [Workout] {
        workouts.filter { $0.needsReflection }.sorted { $0.date > $1.date }
    }

    private func complete(_ workout: Workout) {
        workout.isCompleted = true
        workout.isPlanned = false
        try? context.save()
    }

    private func delete(_ list: [Workout], at offsets: IndexSet) {
        for index in offsets {
            context.delete(list[index])
        }
        try? context.save()
    }
}

private struct PlanRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(workout.type.tint.opacity(0.18)).frame(width: 40, height: 40)
                Image(systemName: workout.type.systemImage)
                    .foregroundStyle(workout.type.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title.isEmpty ? workout.type.label : workout.title)
                    .fontWeight(.medium)
                Text(workout.date, format: .dateTime.weekday(.wide).day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let focus = workout.plannedFocus, !focus.isEmpty {
                    Text(focus).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
