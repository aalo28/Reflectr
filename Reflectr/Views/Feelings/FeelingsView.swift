//
//  FeelingsView.swift
//  Reflectr
//
//  Everything on one page, newest first:
//  Rows are grouped under a date header per day:
//  • a workout row — title, a one-line "how was the day" strip (scores +
//    note), then four columns: Before · During · After · +1 day;
//  • a rest-day row — "Rest day" and the same one-line day strip.
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
                        ForEach(Self.groupedByDay(rows), id: \.day) { group in
                            Text(dayLabel(group.day))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                            ForEach(group.rows) { row in
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

    /// Consecutive rows that fall on the same day, so the date is shown once above them.
    private static func groupedByDay(_ rows: [FeelingsRowItem]) -> [(day: Date, rows: [FeelingsRowItem])] {
        var groups: [(day: Date, rows: [FeelingsRowItem])] = []
        for row in rows {
            let day = row.sortDate.startOfDay
            if groups.last?.day == day {
                groups[groups.count - 1].rows.append(row)
            } else {
                groups.append((day, [row]))
            }
        }
        return groups
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

// MARK: - Shared bits

/// One score: icon + number, tight and never truncated.
private struct Score: View {
    let icon: String
    let value: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text("\(value)").monospacedDigit()
        }
        .fixedSize()
    }
}

/// The scores of a check-in, laid out to fit the space: one line if possible,
/// otherwise wrapped onto two or three.
private struct Scores: View {
    let checkIn: FeelingCheckIn

    var body: some View {
        let items: [(String, Int)] = [
            ("face.smiling", checkIn.feeling),
            ("bolt", checkIn.energy),
            ("bandage", checkIn.soreness),
        ].compactMap { icon, v in v.map { (icon, $0) } }

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { ForEach(items, id: \.0) { Score(icon: $0.0, value: $0.1) } }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) { ForEach(items.prefix(2), id: \.0) { Score(icon: $0.0, value: $0.1) } }
                HStack(spacing: 6) { ForEach(items.dropFirst(2), id: \.0) { Score(icon: $0.0, value: $0.1) } }
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(items, id: \.0) { Score(icon: $0.0, value: $0.1) }
            }
        }
    }
}

/// Date header shown above each day's rows.
private func dayLabel(_ day: Date) -> String {
    let cal = Calendar.current
    let date = day.formatted(.dateTime.weekday(.abbreviated).day().month())
    if cal.isDateInToday(day) { return "Today · \(date)" }
    if cal.isDateInYesterday(day) { return "Yesterday · \(date)" }
    return date
}

// MARK: - Daily line (shared by both row kinds)

/// The day's general feeling on one line: ☀️ scores · note. Tap to edit the
/// first entry (or log one); long-press for the others or to add another.
private struct DailyLine: View {
    let day: Date
    let checkIns: [FeelingCheckIn]
    let onSelect: (DailyEdit) -> Void

    /// New entries for today use the current time; past days default to noon.
    private var defaultDate: Date {
        day.isSameDay(as: .now) ? .now : Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    var body: some View {
        let first = checkIns.first
        // Notes from every entry that day, joined so they fit on the one line.
        let note = checkIns.compactMap { $0.note }.filter { !$0.isEmpty }.joined(separator: " · ")

        Button {
            onSelect(first.map { DailyEdit(target: .existing($0), date: $0.date) }
                     ?? DailyEdit(target: .new(.daily), date: defaultDate))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: CheckInPhase.daily.systemImage)
                    .foregroundStyle(.orange)
                if let first {
                    HStack(spacing: 6) {
                        if let f = first.feeling { Score(icon: "face.smiling", value: f) }
                        if let e = first.energy { Score(icon: "bolt", value: e) }
                        if let s = first.soreness { Score(icon: "bandage", value: s) }
                    }
                    .foregroundStyle(.orange)
                    .fixedSize()
                    if !note.isEmpty {
                        Text(note)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                    if checkIns.count > 1 {
                        Text("+\(checkIns.count - 1)")
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                } else {
                    Text("How did you feel this day?")
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(first == nil ? Color.gray.opacity(0.08) : Color.orange.opacity(0.12))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            ForEach(checkIns) { c in
                Button {
                    onSelect(DailyEdit(target: .existing(c), date: c.date))
                } label: {
                    Label(c.date.formatted(.dateTime.hour().minute()) + ((c.note ?? "").isEmpty ? "" : " — \(c.note!)"),
                          systemImage: "pencil")
                }
            }
            Button {
                onSelect(DailyEdit(target: .new(.daily), date: defaultDate))
            } label: {
                Label(checkIns.isEmpty ? "Log how you felt" : "Add another", systemImage: "plus")
            }
        }
        .accessibilityLabel(first == nil ? "Log how you felt this day" : "How you felt this day. \(note)")
    }
}

// MARK: - Rows

private struct FeelingsRow: View {
    let workout: Workout
    let daily: [FeelingCheckIn]
    let onSelect: (CheckInTarget) -> Void
    let onSelectDaily: (DailyEdit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: workout) {
                HStack(spacing: 8) {
                    Image(systemName: workout.type.systemImage)
                        .foregroundStyle(workout.type.tint)
                        .frame(width: 22)
                    Text(workout.title.isEmpty ? workout.type.label : workout.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            DailyLine(day: workout.date.startOfDay, checkIns: daily, onSelect: onSelectDaily)

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

/// A day without training: "Rest day", then the day's feeling line.
private struct RestDayRow: View {
    let day: Date
    let daily: [FeelingCheckIn]
    let onSelectDaily: (DailyEdit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text("Rest day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            DailyLine(day: day, checkIns: daily, onSelect: onSelectDaily)
        }
        .padding(10)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let c = checkIn {
                Scores(checkIn: c)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
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
