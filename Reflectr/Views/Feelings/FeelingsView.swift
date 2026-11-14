//
//  FeelingsView.swift
//  Reflectr
//
//  Two views:
//  • Daily — one card per day (training or rest) with general check-ins,
//    plus a summary of your baseline and training vs rest days.
//  • Workouts — every completed workout as a row with four columns —
//    Before · During · Right after · +1 day.
//

import SwiftUI
import SwiftData

enum FeelingsMode: String, CaseIterable, Identifiable {
    case daily, workouts
    var id: String { rawValue }
    var label: String { self == .daily ? "Daily" : "Workouts" }
}

struct FeelingsView: View {
    @Query(
        filter: #Predicate<Workout> { $0.isCompleted },
        sort: \Workout.date,
        order: .reverse
    ) private var workouts: [Workout]

    @Query(
        filter: #Predicate<FeelingCheckIn> { $0.phaseRaw == "daily" },
        sort: \FeelingCheckIn.date,
        order: .reverse
    ) private var dailyCheckIns: [FeelingCheckIn]

    @AppStorage("feelingsMode") private var mode: FeelingsMode = .daily
    @State private var editing: (workout: Workout, target: CheckInTarget)?
    @State private var editingDaily: DailyEdit?

    var body: some View {
        NavigationStack {
            ScrollView {
                Picker("View", selection: $mode) {
                    ForEach(FeelingsMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 4)

                switch mode {
                case .daily:
                    DailyFeelingsList(
                        checkIns: dailyCheckIns,
                        workouts: workouts,
                        onSelect: { editingDaily = $0 }
                    )
                    .padding(.horizontal)
                    .padding(.bottom)
                case .workouts:
                    workoutGrid
                }
            }
            .scrollContentBackground(.hidden)
            .background(BackgroundGradient())
            .navigationTitle("Feelings")
            .toolbar {
                if mode == .daily {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            editingDaily = DailyEdit(target: .new(.daily), date: .now)
                        } label: {
                            Label("Log how you feel", systemImage: "plus")
                        }
                    }
                }
            }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .sheet(isPresented: Binding(
                get: { editing != nil },
                set: { if !$0 { editing = nil } }
            )) {
                if let editing {
                    CheckInEditorView(workout: editing.workout, target: editing.target)
                }
            }
            .sheet(item: $editingDaily) { edit in
                CheckInEditorView(workout: nil, target: edit.target, initialDate: edit.date)
            }
        }
    }

    private var workoutGrid: some View {
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

    private var columnHeader: some View {
        HStack(spacing: 6) {
            ForEach(CheckInPhase.workoutPhases) { phase in
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

// MARK: - Daily

struct DailyEdit: Identifiable {
    let id = UUID()
    let target: CheckInTarget
    let date: Date
}

/// One card per day — today and the past two weeks always, plus any older day
/// with a daily check-in — showing general check-ins and any workouts that day.
private struct DailyFeelingsList: View {
    let checkIns: [FeelingCheckIn]
    let workouts: [Workout]
    let onSelect: (DailyEdit) -> Void

    private var checkInsByDay: [Date: [FeelingCheckIn]] {
        Dictionary(grouping: checkIns, by: { $0.date.startOfDay })
    }

    private var workoutsByDay: [Date: [Workout]] {
        Dictionary(grouping: workouts, by: { $0.date.startOfDay })
    }

    private var days: [Date] {
        let today = Date.now.startOfDay
        var set = Set((0..<14).map { today.addingDays(-$0) })
        set.formUnion(checkInsByDay.keys.filter { $0 <= today })
        return set.sorted(by: >)
    }

    var body: some View {
        let byDay = checkInsByDay
        let wByDay = workoutsByDay
        LazyVStack(spacing: 10) {
            DailySummaryCard(checkInsByDay: byDay, workoutsByDay: wByDay)
            ForEach(days, id: \.self) { day in
                DayCard(
                    day: day,
                    checkIns: (byDay[day] ?? []).sorted { $0.date < $1.date },
                    workouts: wByDay[day] ?? [],
                    onSelect: onSelect
                )
            }
        }
    }
}

/// Average daily feeling/energy over the last 7 and 30 days, and training vs rest days.
private struct DailySummaryCard: View {
    let checkInsByDay: [Date: [FeelingCheckIn]]
    let workoutsByDay: [Date: [Workout]]

    var body: some View {
        let today = Date.now.startOfDay
        let last7 = stats(since: today.addingDays(-6))
        let last30 = stats(since: today.addingDays(-29))
        let training = stats(since: .distantPast) { workoutsByDay[$0] != nil }
        let rest = stats(since: .distantPast) { workoutsByDay[$0] == nil }

        VStack(alignment: .leading, spacing: 10) {
            Label("In general", systemImage: "sun.max")
                .font(.subheadline.bold())
            if checkInsByDay.isEmpty {
                Text("Log how you feel each day — training or not — to see your baseline here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                    GridRow {
                        Text("").gridColumnAlignment(.leading)
                        Image(systemName: "face.smiling")
                        Image(systemName: "bolt")
                        Text("days").font(.caption2)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    row("Last 7 days", last7)
                    row("Last 30 days", last30)
                    Divider().gridCellColumns(4)
                    row("Training days", training)
                    row("Rest days", rest)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private struct Stats { var feeling: Double?; var energy: Double?; var days: Int }

    private func stats(since start: Date, where include: (Date) -> Bool = { _ in true }) -> Stats {
        let entries = checkInsByDay.filter { $0.key >= start && include($0.key) }
        let all = entries.values.flatMap { $0 }
        func avg(_ values: [Int]) -> Double? {
            values.isEmpty ? nil : Double(values.reduce(0, +)) / Double(values.count)
        }
        return Stats(
            feeling: avg(all.compactMap(\.feeling)),
            energy: avg(all.compactMap(\.energy)),
            days: entries.count
        )
    }

    private func row(_ title: String, _ s: Stats) -> some View {
        GridRow {
            Text(title).font(.caption)
            value(s.feeling)
            value(s.energy)
            Text("\(s.days)").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func value(_ v: Double?) -> some View {
        Text(v.map { String(format: "%.1f", $0) } ?? "–")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(v == nil ? Color.secondary : Color.accentColor)
    }
}

private struct DayCard: View {
    let day: Date
    let checkIns: [FeelingCheckIn]
    let workouts: [Workout]
    let onSelect: (DailyEdit) -> Void

    /// New entries for today use the current time; past days default to noon.
    private var defaultDate: Date {
        day.isSameDay(as: .now) ? .now : Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(dayTitle).font(.subheadline.weight(.semibold))
                    Text(workouts.isEmpty ? "Rest day" : workouts.map(\.displayTitle).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    onSelect(DailyEdit(target: .new(.daily), date: defaultDate))
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel("Log how you felt on \(dayTitle)")
            }

            if checkIns.isEmpty {
                Text("No check-in")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            ForEach(checkIns) { c in
                Button {
                    onSelect(DailyEdit(target: .existing(c), date: c.date))
                } label: {
                    DailyCheckInRow(checkIn: c)
                }
                .buttonStyle(.plain)
            }

            ForEach(workouts) { w in
                NavigationLink(value: w) {
                    WorkoutFeelingStrip(workout: w)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var dayTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month())
    }
}

private struct DailyCheckInRow: View {
    let checkIn: FeelingCheckIn

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                Text(checkIn.date, format: .dateTime.hour().minute())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let f = checkIn.feeling { score("face.smiling", f) }
                if let e = checkIn.energy { score("bolt", e) }
                if let s = checkIn.soreness { score("bandage", s) }
                Spacer(minLength: 0)
            }
            if let note = checkIn.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.10)))
        .contentShape(Rectangle())
    }

    private func score(_ icon: String, _ value: Int) -> some View {
        Label("\(value)", systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
    }
}

/// Compact line for a workout on a day card: icon + the feeling score per phase.
private struct WorkoutFeelingStrip: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: workout.type.systemImage)
                .foregroundStyle(workout.type.tint)
                .font(.caption)
            ForEach(CheckInPhase.workoutPhases) { phase in
                let f = workout.checkIns(for: phase).first?.feeling
                HStack(spacing: 2) {
                    Image(systemName: phase.systemImage)
                    Text(f.map(String.init) ?? "–")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(f == nil ? Color.secondary : Color.accentColor)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.08)))
        .contentShape(Rectangle())
        .accessibilityLabel("\(workout.displayTitle) feelings")
    }
}

private extension Workout {
    var displayTitle: String { title.isEmpty ? type.label : title }
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
                ForEach(CheckInPhase.workoutPhases) { phase in
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
        case .daily: "Day"
        }
    }
}
