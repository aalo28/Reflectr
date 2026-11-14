//
//  FeelingsView.swift
//  Reflectr
//
//  Everything on one page, newest first:
//  • a workout row — title (with the day's general feeling as a chip), then
//    four columns: Before · During · After · +1 day;
//  • a rest-day row — one line: date, "Rest day", the day's general feeling.
//  A summary card on top compares your baseline on training vs rest days.
//

import SwiftUI
import SwiftData

struct FeelingsView: View {
    @Query(
        filter: #Predicate<Workout> { $0.isCompleted },
        sort: \Workout.date,
        order: .reverse
    ) private var workouts: [Workout]

    @Query(
        filter: #Predicate<FeelingCheckIn> { $0.phaseRaw == "daily" },
        sort: \FeelingCheckIn.date
    ) private var dailyCheckIns: [FeelingCheckIn]

    @State private var editing: (workout: Workout, target: CheckInTarget)?
    @State private var editingDaily: DailyEdit?

    var body: some View {
        let dailyByDay = Dictionary(grouping: dailyCheckIns, by: { $0.date.startOfDay })
        let workoutsByDay = Dictionary(grouping: workouts, by: { $0.date.startOfDay })
        let rows = Self.rows(workouts: workouts, workoutDays: Set(workoutsByDay.keys), dailyDays: Set(dailyByDay.keys))

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                    DailySummaryCard(checkInsByDay: dailyByDay, workoutsByDay: workoutsByDay)
                    Section {
                        ForEach(rows) { row in
                            switch row {
                            case .workout(let workout):
                                FeelingsRow(
                                    workout: workout,
                                    daily: dailyByDay[workout.date.startOfDay] ?? [],
                                    onSelect: { editing = (workout, $0) },
                                    onSelectDaily: { editingDaily = $0 }
                                )
                            case .restDay(let day):
                                RestDayRow(
                                    day: day,
                                    daily: dailyByDay[day] ?? [],
                                    onSelectDaily: { editingDaily = $0 }
                                )
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingDaily = DailyEdit(target: .new(.daily), date: .now)
                    } label: {
                        Label("Log how you feel today", systemImage: "plus")
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

    /// Workouts plus rest days, newest first. Rest days shown: the last two
    /// weeks (so you can fill them in) and any older day with a daily check-in.
    private static func rows(workouts: [Workout], workoutDays: Set<Date>, dailyDays: Set<Date>) -> [FeelingsRowItem] {
        let today = Date.now.startOfDay
        var restDays = Set((0..<14).map { today.addingDays(-$0) })
        restDays.formUnion(dailyDays.filter { $0 <= today })
        restDays.subtract(workoutDays)

        let items = workouts.map(FeelingsRowItem.workout) + restDays.map(FeelingsRowItem.restDay)
        // Same day: rest-day can't collide with workouts; workouts keep their time order.
        return items.sorted { $0.sortDate > $1.sortDate }
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

private enum FeelingsRowItem: Identifiable {
    case workout(Workout)
    case restDay(Date)

    var id: String {
        switch self {
        case .workout(let w): "w-\(w.persistentModelID.hashValue)"
        case .restDay(let d): "r-\(d.timeIntervalSinceReferenceDate)"
        }
    }

    var sortDate: Date {
        switch self {
        case .workout(let w): w.date
        case .restDay(let d): d
        }
    }
}

struct DailyEdit: Identifiable {
    let id = UUID()
    let target: CheckInTarget
    let date: Date
}

// MARK: - Daily chip (shared by both row kinds)

/// The day's general feeling, compact enough to sit on a single line.
/// Tap to edit the first entry (or log one); long-press for the others or to add another.
private struct DailyChip: View {
    let day: Date
    let checkIns: [FeelingCheckIn]
    let onSelect: (DailyEdit) -> Void

    /// New entries for today use the current time; past days default to noon.
    private var defaultDate: Date {
        day.isSameDay(as: .now) ? .now : Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    var body: some View {
        let first = checkIns.first
        Button {
            onSelect(first.map { DailyEdit(target: .existing($0), date: $0.date) }
                     ?? DailyEdit(target: .new(.daily), date: defaultDate))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: CheckInPhase.daily.systemImage)
                if let c = first {
                    if let f = c.feeling { score("face.smiling", f) }
                    if let e = c.energy { score("bolt", e) }
                    if let s = c.soreness { score("bandage", s) }
                    if c.feeling == nil && c.energy == nil && c.soreness == nil {
                        Image(systemName: "text.alignleft")
                    }
                    if checkIns.count > 1 {
                        Text("+\(checkIns.count - 1)").foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "plus").foregroundStyle(.secondary)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(first == nil ? Color.secondary : Color.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(first == nil ? Color.gray.opacity(0.10) : Color.orange.opacity(0.14))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            ForEach(checkIns) { c in
                Button {
                    onSelect(DailyEdit(target: .existing(c), date: c.date))
                } label: {
                    Label(c.date.formatted(.dateTime.hour().minute()), systemImage: "pencil")
                }
            }
            Button {
                onSelect(DailyEdit(target: .new(.daily), date: defaultDate))
            } label: {
                Label(checkIns.isEmpty ? "Log how you felt" : "Add another", systemImage: "plus")
            }
        }
        .accessibilityLabel(first == nil ? "Log how you felt this day" : "How you felt this day: \(first?.note ?? "logged")")
    }

    private func score(_ icon: String, _ value: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text("\(value)")
        }
    }
}

// MARK: - Rows

private struct FeelingsRow: View {
    let workout: Workout
    let daily: [FeelingCheckIn]
    let onSelect: (CheckInTarget) -> Void
    let onSelectDaily: (DailyEdit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
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
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                DailyChip(day: workout.date.startOfDay, checkIns: daily, onSelect: onSelectDaily)

                NavigationLink(value: workout) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

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

/// A day without training, on a single line: date · "Rest day" · the day's feeling.
private struct RestDayRow: View {
    let day: Date
    let daily: [FeelingCheckIn]
    let onSelectDaily: (DailyEdit) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("Rest day")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            DailyChip(day: day, checkIns: daily, onSelect: onSelectDaily)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
    }

    private var title: String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month())
    }
}

// MARK: - Summary

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

private struct FeelingCell: View {
    let checkIn: FeelingCheckIn?
    var tint: Color = .accentColor
    /// More entries exist than the one shown (e.g. a second daily check-in).
    var extraCount: Int = 0

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
                if extraCount > 0 {
                    Text("+\(extraCount) more").font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
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
                .fill(checkIn == nil ? Color.gray.opacity(0.08) : tint.opacity(0.12))
        )
        .contentShape(Rectangle())
    }

    private func score(_ icon: String, _ value: Int) -> some View {
        Label("\(value)", systemImage: icon)
            .labelStyle(.titleAndIcon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
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
