//
//  FeelingCheckInViews.swift
//  Reflectr
//
//  The "how did I feel over time" timeline on a workout (before → during →
//  right after → days later), and the small sheet used to log each moment.
//

import SwiftUI
import SwiftData

/// What the check-in sheet is editing: a new entry for a phase, or an existing one.
enum CheckInTarget: Identifiable {
    case new(CheckInPhase)
    case existing(FeelingCheckIn)

    var id: String {
        switch self {
        case .new(let phase): "new-\(phase.rawValue)"
        case .existing(let c): "existing-\(c.id?.uuidString ?? "")"
        }
    }
}

// MARK: - Timeline card

struct FeelingTimelineCard: View {
    let workout: Workout
    let onSelect: (CheckInTarget) -> Void

    /// Before a planned session is done, only "before" and "during" make sense.
    private var phases: [CheckInPhase] {
        workout.isPlanned && !workout.isCompleted ? [.before, .during] : CheckInPhase.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How you felt", systemImage: "waveform.path.ecg")
                .font(.subheadline.bold())

            ForEach(Array(phases.enumerated()), id: \.element) { index, phase in
                phaseRow(phase)
                if index < phases.count - 1 { Divider() }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func phaseRow(_ phase: CheckInPhase) -> some View {
        let entries = workout.checkIns(for: phase)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: phase.systemImage)
                .font(.callout)
                .foregroundStyle(entries.isEmpty ? Color.secondary : Color.accentColor)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(phase.label).font(.callout.weight(.medium))

                if entries.isEmpty {
                    Text(phase.prompt).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        Button { onSelect(.existing(entry)) } label: {
                            CheckInSummaryRow(checkIn: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)

            if entries.isEmpty || phase.allowsMultiple {
                Button { onSelect(.new(phase)) } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Log \(phase.label.lowercased())")
            }
        }
    }
}

private struct CheckInSummaryRow: View {
    let checkIn: FeelingCheckIn

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                if let rel = checkIn.relativeLabel {
                    Text(rel).font(.caption.bold()).foregroundStyle(.secondary)
                }
                value("face.smiling", checkIn.feeling)
                value("bolt", checkIn.energy)
                value("bandage", checkIn.soreness)
            }
            if let note = checkIn.note, !note.isEmpty {
                Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func value(_ icon: String, _ v: Int?) -> some View {
        if let v {
            Label("\(v)", systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
    }
}

// MARK: - Editor sheet

struct CheckInEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let workout: Workout
    let target: CheckInTarget

    @State private var feeling: Int?
    @State private var energy: Int?
    @State private var soreness: Int?
    @State private var note = ""
    @State private var date = Date.now

    private var phase: CheckInPhase {
        switch target {
        case .new(let p): p
        case .existing(let c): c.phase
        }
    }

    private var existing: FeelingCheckIn? {
        if case .existing(let c) = target { c } else { nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(phase.prompt) {
                    RatingPicker(title: "Feeling", systemImage: "face.smiling", range: 1...5, selection: $feeling)
                    RatingPicker(title: "Energy", systemImage: "bolt", range: 1...5, selection: $energy)
                    if phase.tracksSoreness {
                        RatingPicker(title: "Soreness (1 none · 5 very)", systemImage: "bandage", range: 1...5, selection: $soreness)
                    }
                }

                Section("Note") {
                    TextField("Anything worth remembering…", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    DatePicker("Logged", selection: $date)
                }

                if existing != nil {
                    Section {
                        Button("Delete check-in", role: .destructive, action: delete)
                    }
                }
            }
            .navigationTitle(phase.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(feeling == nil && energy == nil && soreness == nil
                                  && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.medium, .large])
    }

    private func load() {
        guard let c = existing else { return }
        feeling = c.feeling
        energy = c.energy
        soreness = c.soreness
        note = c.note ?? ""
        date = c.date
    }

    private func save() {
        let checkIn = existing ?? {
            let new = FeelingCheckIn(phase: phase)
            context.insert(new)
            new.workout = workout
            return new
        }()
        checkIn.feeling = feeling
        checkIn.energy = energy
        checkIn.soreness = phase.tracksSoreness ? soreness : nil
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        checkIn.note = trimmed.isEmpty ? nil : trimmed
        checkIn.date = date
        try? context.save()
        dismiss()
    }

    private func delete() {
        if let c = existing { context.delete(c) }
        try? context.save()
        dismiss()
    }
}
