//
//  AddWorkoutView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

/// Creates a planned or completed workout, or edits an existing one.
struct AddWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let editing: Workout?

    @State private var title = ""
    @State private var type: WorkoutType = .run
    @State private var date: Date
    @State private var isPlanned: Bool
    @State private var plannedFocus = ""
    @State private var notes = ""

    // Optional metrics for a manually-logged completed workout.
    @State private var durationMinutes = ""
    @State private var distanceKm = ""

    /// New workout.
    init(defaultDate: Date = .now, startPlanned: Bool = false) {
        self.editing = nil
        _date = State(initialValue: defaultDate)
        _isPlanned = State(initialValue: startPlanned)
    }

    /// Edit an existing workout.
    init(editing workout: Workout) {
        self.editing = workout
        _title = State(initialValue: workout.title)
        _type = State(initialValue: workout.type)
        _date = State(initialValue: workout.date)
        _isPlanned = State(initialValue: workout.isPlanned && !workout.isCompleted)
        _plannedFocus = State(initialValue: workout.plannedFocus ?? "")
        _notes = State(initialValue: workout.notes ?? "")
        if let d = workout.durationMinutes { _durationMinutes = State(initialValue: String(Int(d.rounded()))) }
        if let km = workout.distanceKm { _distanceKm = State(initialValue: String(format: "%.1f", km)) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(WorkoutType.allCases) { t in
                            Label(t.label, systemImage: t.systemImage).tag(t)
                        }
                    }
                    TextField("Title (optional)", text: $title)
                    DatePicker("Date", selection: $date)
                }

                Section {
                    Toggle("Planned session", isOn: $isPlanned)
                } footer: {
                    Text(isPlanned
                         ? "Shows up in your plan. Mark it complete after training, then reflect."
                         : "Logged as completed — you can add a reflection right away.")
                }

                if isPlanned {
                    Section("Focus") {
                        TextField("e.g. tempo, technique, heavy squats", text: $plannedFocus, axis: .vertical)
                            .lineLimit(1...3)
                    }
                } else {
                    Section("Metrics (optional)") {
                        HStack {
                            Text("Duration")
                            Spacer()
                            TextField("min", text: $durationMinutes)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Distance")
                            Spacer()
                            TextField("km", text: $distanceKm)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Anything to remember", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle(editing == nil ? "New Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        let workout = editing ?? Workout()
        if editing == nil { context.insert(workout) }

        workout.title = title.trimmingCharacters(in: .whitespaces)
        workout.type = type
        workout.date = date
        workout.isPlanned = isPlanned
        workout.isCompleted = !isPlanned ? true : (editing?.isCompleted ?? false)
        if editing == nil {
            workout.source = isPlanned ? WorkoutSource.planned.rawValue : WorkoutSource.manual.rawValue
        }
        workout.plannedFocus = plannedFocus.isEmpty ? nil : plannedFocus
        workout.notes = notes.isEmpty ? nil : notes

        if !isPlanned {
            workout.durationMinutes = Double(durationMinutes)
            if let km = Double(distanceKm.replacingOccurrences(of: ",", with: ".")) {
                workout.distanceMeters = km * 1000
            }
        }

        try? context.save()
        dismiss()
    }
}
