//
//  CalendarView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var visibleMonth: Date = Date.now.startOfDay
    @State private var selectedDay: Date = Date.now.startOfDay
    @State private var mode: CalendarMode = .month
    @State private var showAdd = false
    @State private var showImport = false
    @State private var showSettings = false

    private let calendar = Calendar.current

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.calendarPath) {
            ScrollView {
                VStack(spacing: 20) {
                    modePicker
                    if mode == .month {
                        monthCard
                        dayCard
                    } else {
                        weekCard
                        weekListCard
                    }
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(BackgroundGradient())
            .navigationTitle("Training")
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
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
                AddWorkoutView(defaultDate: selectedDay, startPlanned: selectedDay > Date.now)
            }
            .sheet(isPresented: $showImport) {
                ImportWorkoutView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var modePicker: some View {
        Picker("View", selection: $mode) {
            Text("Month").tag(CalendarMode.month)
            Text("Week").tag(CalendarMode.week)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Week view

    private var weekCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button { changeWeek(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(weekRangeTitle).font(.headline)
                Spacer()
                Button { changeWeek(1) } label: { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 4) {
                ForEach(weekDays, id: \.self) { day in
                    VStack(spacing: 4) {
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        DayCell(
                            day: day,
                            isSelected: day.isSameDay(as: selectedDay),
                            isToday: day.isSameDay(as: Date.now),
                            workouts: workouts(on: day)
                        )
                        .onTapGesture { selectedDay = day }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    /// Every day of the selected week, each with its workouts — a week-at-a-glance.
    private var weekListCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(weekDays, id: \.self) { day in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(day, format: .dateTime.weekday(.wide).day().month())
                            .font(.subheadline.bold())
                            .foregroundStyle(day.isSameDay(as: Date.now) ? Color.accentColor : .primary)
                        Spacer()
                        Button {
                            selectedDay = day
                            showAdd = true
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.secondary)
                        }
                    }

                    let dayWorkouts = workouts(on: day)
                    if dayWorkouts.isEmpty {
                        Text(day > Date.now ? "—" : "Rest day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dayWorkouts) { workout in
                            NavigationLink(value: workout) {
                                WorkoutRowView(workout: workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if day != weekDays.last { Divider() }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Month grid

    private var monthCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(monthTitle)
                    .font(.headline)
                Spacer()
                Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal, 4)

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(monthDays.indices, id: \.self) { index in
                    if let day = monthDays[index] {
                        DayCell(
                            day: day,
                            isSelected: day.isSameDay(as: selectedDay),
                            isToday: day.isSameDay(as: Date.now),
                            workouts: workouts(on: day)
                        )
                        .onTapGesture { selectedDay = day }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Selected day

    private var dayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDay, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.headline)
                Spacer()
                Button {
                    showAdd = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
            }

            let dayWorkouts = workouts(on: selectedDay)
            if dayWorkouts.isEmpty {
                emptyDay
            } else {
                ForEach(dayWorkouts) { workout in
                    NavigationLink(value: workout) {
                        WorkoutRowView(workout: workout)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var emptyDay: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz")
                .font(.title)
                .foregroundStyle(.secondary)
            Text(selectedDay > Date.now ? "Nothing planned yet" : "No training logged")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(selectedDay > Date.now ? "Plan a workout" : "Log a workout") {
                showAdd = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private func workouts(on day: Date) -> [Workout] {
        workouts
            .filter { $0.date.isSameDay(as: day) }
            .sorted { $0.date < $1.date }
    }

    private func changeMonth(_ delta: Int) {
        withAnimation(.snappy) {
            visibleMonth = visibleMonth.addingMonths(delta)
        }
    }

    private func changeWeek(_ delta: Int) {
        withAnimation(.snappy) {
            selectedDay = selectedDay.addingWeeks(delta)
        }
    }

    /// The seven days of the week containing `selectedDay`.
    private var weekDays: [Date] {
        let start = selectedDay.startOfWeek
        return (0..<7).map { start.addingDays($0) }
    }

    private var weekRangeTitle: String {
        let start = selectedDay.startOfWeek
        let end = start.addingDays(6)
        let s = start.formatted(.dateTime.day().month(.abbreviated))
        let e = end.formatted(.dateTime.day().month(.abbreviated))
        return "\(s) – \(e)"
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The month laid out as a 7-wide grid, with leading nils for the offset.
    private var monthDays: [Date?] {
        guard
            let interval = calendar.dateInterval(of: .month, for: visibleMonth),
            let firstWeekday = calendar.dateComponents([.weekday], from: interval.start).weekday
        else { return [] }

        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)

        var day = interval.start
        while day < interval.end {
            cells.append(day)
            day = day.addingDays(1)
        }
        return cells
    }
}

private enum CalendarMode {
    case month
    case week
}

// MARK: - Day cell

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let workouts: [Workout]

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.callout)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary))

            HStack(spacing: 2) {
                ForEach(Array(workouts.prefix(3).enumerated()), id: \.offset) { _, workout in
                    Circle()
                        .strokeBorder(workout.type.tint, lineWidth: workout.isCompleted ? 0 : 1.5)
                        .background(Circle().fill(workout.isCompleted ? workout.type.tint : .clear))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor : .clear)
        )
    }
}
