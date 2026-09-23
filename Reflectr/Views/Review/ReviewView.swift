//
//  ReviewView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//
//  The "look back at the end of the week" view: how this week compared to last,
//  the follow-ups you set for yourself, and recurring themes across sessions.

import SwiftUI
import SwiftData
import Charts

struct ReviewView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    /// 0 = this week, 1 = last week, …
    @State private var weeksAgo = 0

    private var weekStart: Date { Date.now.startOfWeek.addingWeeks(-weeksAgo) }
    private var weekEnd: Date { weekStart.addingWeeks(1) }
    private var prevStart: Date { weekStart.addingWeeks(-1) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weekPicker
                    statsCard
                    trendCard
                    followUpsCard
                    themesCard
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .background(BackgroundGradient())
            .navigationTitle("Review")
        }
    }

    // MARK: - Week selector

    private var weekPicker: some View {
        HStack {
            Button { weeksAgo += 1 } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack(spacing: 2) {
                Text(weekLabel).font(.headline)
                Text("\(weekStart.formatted(.dateTime.day().month())) – \(weekEnd.addingDays(-1).formatted(.dateTime.day().month()))")
            }
            .font(.subheadline)
            Spacer()
            Button { weeksAgo = max(0, weeksAgo - 1) } label: { Image(systemName: "chevron.right") }
                .disabled(weeksAgo == 0)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weekLabel: String {
        switch weeksAgo {
        case 0: return "This week"
        case 1: return "Last week"
        default: return "\(weeksAgo) weeks ago"
        }
    }

    // MARK: - Stats vs previous week

    private var statsCard: some View {
        let now = summary(from: weekStart, to: weekEnd)
        let prev = summary(from: prevStart, to: weekStart)
        return VStack(spacing: 14) {
            HStack {
                statTile("Sessions", "\(now.count)", delta: Double(now.count - prev.count), isInt: true)
                statTile("Time", "\(now.totalMinutes)m", delta: Double(now.totalMinutes - prev.totalMinutes), isInt: true)
            }
            HStack {
                statTile("Avg feeling", now.avgFeeling.map { String(format: "%.1f", $0) } ?? "—",
                         delta: deltaDouble(now.avgFeeling, prev.avgFeeling))
                statTile("Avg effort", now.avgRPE.map { String(format: "%.1f", $0) } ?? "—",
                         delta: deltaDouble(now.avgRPE, prev.avgRPE))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statTile(_ label: String, _ value: String, delta: Double, isInt: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
            if delta != 0 {
                let up = delta > 0
                Label(
                    isInt ? "\(abs(Int(delta)))" : String(format: "%.1f", abs(delta)),
                    systemImage: up ? "arrow.up" : "arrow.down"
                )
                .font(.caption2)
                .foregroundStyle(up ? .green : .orange)
            } else {
                Text("—").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trend chart (last 6 weeks)

    private var trendCard: some View {
        let points = weeklyFeelingTrend()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Feeling trend").font(.subheadline.bold())
            if points.allSatisfy({ $0.value == 0 }) {
                Text("Add reflections to see how your weeks trend.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("Week", point.label),
                        y: .value("Avg feeling", point.value)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .chartYScale(domain: 0...5)
                .frame(height: 140)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Follow-ups ("what to try next time")

    private var followUpsCard: some View {
        let items = collect(\.tryNextTime)
        return VStack(alignment: .leading, spacing: 10) {
            Label("Follow-ups from this week", systemImage: "flask")
                .font(.subheadline.bold())
                .foregroundStyle(Color.accentColor)
            if items.isEmpty {
                Text("Nothing to carry forward yet.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle").font(.system(size: 8)).padding(.top, 6)
                        Text(line).font(.callout)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recurring themes (tags + "what wasn't optimal")

    private var themesCard: some View {
        let tagCounts = tagFrequencies()
        let issues = collect(\.whatWasntOptimal)
        return VStack(alignment: .leading, spacing: 12) {
            Label("Recurring themes", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(Color.accentColor)
            if tagCounts.isEmpty && issues.isEmpty {
                Text("Tag your reflections to spot patterns over time.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !tagCounts.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tagCounts, id: \.0) { tag, count in
                        Text("\(tag) ×\(count)")
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            if !issues.isEmpty {
                Divider()
                Text("What wasn't optimal").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(issues, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2).foregroundStyle(.orange).padding(.top, 3)
                        Text(line).font(.callout)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Data helpers

    private struct WeekSummary {
        var count = 0
        var totalMinutes = 0
        var avgFeeling: Double?
        var avgRPE: Double?
    }

    private func workoutsInWeek(from start: Date, to end: Date) -> [Workout] {
        workouts.filter { $0.isCompleted && $0.date >= start && $0.date < end }
    }

    private func summary(from start: Date, to end: Date) -> WeekSummary {
        let items = workoutsInWeek(from: start, to: end)
        var s = WeekSummary()
        s.count = items.count
        s.totalMinutes = items.reduce(0) { $0 + Int(($1.durationMinutes ?? 0).rounded()) }
        s.avgFeeling = average(items.compactMap { $0.reflection?.feeling })
        s.avgRPE = average(items.compactMap { $0.reflection?.rpe })
        return s
    }

    private func average(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private func deltaDouble(_ a: Double?, _ b: Double?) -> Double {
        guard let a, let b else { return 0 }
        return a - b
    }

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    private func weeklyFeelingTrend() -> [TrendPoint] {
        var points: [TrendPoint] = []
        for offset in stride(from: 5, through: 0, by: -1) {
            let start = Date.now.startOfWeek.addingWeeks(-offset)
            let end = start.addingWeeks(1)
            let avg = summary(from: start, to: end).avgFeeling ?? 0
            let label = start.formatted(.dateTime.day().month(.abbreviated))
            points.append(TrendPoint(label: label, value: avg))
        }
        return points
    }

    /// Collect a text field from this week's reflections, newest first, de-duplicated.
    private func collect(_ keyPath: KeyPath<Reflection, String?>) -> [String] {
        let items = workoutsInWeek(from: weekStart, to: weekEnd)
        var result: [String] = []
        for workout in items {
            if let value = workout.reflection?[keyPath: keyPath],
               !value.isEmpty, !result.contains(value) {
                result.append(value)
            }
        }
        return result
    }

    private func tagFrequencies() -> [(String, Int)] {
        let items = workoutsInWeek(from: weekStart, to: weekEnd)
        var counts: [String: Int] = [:]
        for workout in items {
            for tag in workout.reflection?.tags ?? [] {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
    }
}
