//
//  StrongWorkoutParser.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//
//  Parses the plain-text workout export from the Strong app, e.g.:
//
//      Afternoon Workout
//      Monday, 21 September 2026 at 16:41
//
//      Explosive Pull up
//      Set 1: 5 reps
//      Set 2: 5 reps
//
//      Hammer Curl (Dumbbell)
//      Set 1: 16 kg × 6
//      ...
//      Notes: Front delt failure?
//      https://link.strong.app/...

import Foundation
import SwiftData

// MARK: - Intermediate value types (not persisted)

struct ParsedWorkout {
    var title: String
    var date: Date
    var exercises: [ParsedExercise]

    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var isEmpty: Bool { exercises.isEmpty }
}

struct ParsedExercise {
    var name: String
    var sets: [ParsedSet] = []
    var notes: String?
}

struct ParsedSet {
    var reps: Int?
    var weightKg: Double?
}

// MARK: - Parser

enum StrongWorkoutParser {

    /// Parse the raw export text. Returns `nil` if no exercises could be found.
    static func parse(_ raw: String) -> ParsedWorkout? {
        let rawLines = raw.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }

        var title = "Strength Workout"
        var date = Date.now
        var exercises: [ParsedExercise] = []
        var current: ParsedExercise?

        var haveTitle = false
        var haveDate = false

        func flush() {
            if let ex = current, !ex.name.isEmpty { exercises.append(ex) }
            current = nil
        }

        for line in lines {
            if line.isEmpty { continue }
            if isShareLink(line) { continue }

            // Header: first meaningful line is the title, then (optionally) a date.
            if !haveTitle {
                title = line
                haveTitle = true
                continue
            }
            if !haveDate, let parsed = parseDate(line) {
                date = parsed
                haveDate = true
                continue
            }

            if let notes = notesText(line) {
                current?.notes = notes
                continue
            }

            if let set = parseSetLine(line) {
                current?.sets.append(set)
                continue
            }

            // Anything else starts a new exercise.
            haveDate = true // a non-date line here means the date (if any) is past
            flush()
            current = ParsedExercise(name: line)
        }
        flush()

        guard !exercises.isEmpty else { return nil }
        return ParsedWorkout(title: title, date: date, exercises: exercises)
    }

    /// Insert a parsed workout (and its exercises/sets) into the context.
    @discardableResult
    @MainActor
    static func insert(_ parsed: ParsedWorkout, into context: ModelContext) -> Workout {
        let workout = Workout(
            date: parsed.date,
            title: parsed.title,
            type: .strength,
            isPlanned: false,
            isCompleted: true,
            source: .imported
        )
        context.insert(workout)

        var exercises: [Exercise] = []
        for (i, pe) in parsed.exercises.enumerated() {
            let exercise = Exercise(name: pe.name, order: i, logNotes: pe.notes, workout: workout)
            context.insert(exercise)
            var sets: [ExerciseSet] = []
            for (j, ps) in pe.sets.enumerated() {
                let set = ExerciseSet(order: j, reps: ps.reps, weightKg: ps.weightKg, exercise: exercise)
                context.insert(set)
                sets.append(set)
            }
            exercise.sets = sets
            exercises.append(exercise)
        }
        workout.exercises = exercises

        try? context.save()
        return workout
    }

    // MARK: - Line helpers

    private static func isShareLink(_ line: String) -> Bool {
        let l = line.lowercased()
        return l.hasPrefix("http://") || l.hasPrefix("https://")
    }

    private static func notesText(_ line: String) -> String? {
        guard line.lowercased().hasPrefix("notes:") else { return nil }
        let value = line.dropFirst("notes:".count).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// Parse a "Set N: …" line into reps/weight. Returns nil if not a set line.
    private static func parseSetLine(_ line: String) -> ParsedSet? {
        guard line.lowercased().hasPrefix("set"),
              let colon = line.firstIndex(of: ":") else { return nil }
        let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        return parseSetValue(value)
    }

    /// Parse the value part, e.g. "16 kg × 6", "5 lbs x 8", "6 reps", "0 reps".
    static func parseSetValue(_ raw: String) -> ParsedSet {
        var v = raw.lowercased().replacingOccurrences(of: ",", with: ".")
        // Normalise the various "×" separators to a single 'x'.
        v = v.replacingOccurrences(of: "×", with: "x")

        var weightKg: Double?
        var reps: Int?

        if let unitRange = v.range(of: "kg") ?? v.range(of: "lbs") ?? v.range(of: "lb") {
            let unit = v[unitRange]
            let before = v[v.startIndex..<unitRange.lowerBound]
                .replacingOccurrences(of: "+", with: "")
            if let w = firstDouble(in: before) {
                weightKg = unit == "kg" ? w : w * 0.453592
            }
            reps = firstInt(in: v[unitRange.upperBound...])
        } else {
            // Reps only (bodyweight).
            reps = firstInt(in: v)
        }

        return ParsedSet(reps: reps, weightKg: weightKg)
    }

    private static func parseDate(_ line: String) -> Date? {
        let formats = [
            "EEEE, d MMMM yyyy 'at' HH:mm",
            "EEEE, MMMM d, yyyy 'at' h:mm a",
            "d MMMM yyyy 'at' HH:mm",
            "MMM d, yyyy, h:mm a",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: line) { return date }
        }
        return nil
    }

    // MARK: - Number scanning

    private static func firstInt(in s: some StringProtocol) -> Int? {
        firstDouble(in: s).map { Int($0.rounded()) }
    }

    private static func firstDouble(in s: some StringProtocol) -> Double? {
        var number = ""
        for ch in s {
            if ch.isNumber || ch == "." {
                number.append(ch)
            } else if !number.isEmpty {
                break
            }
        }
        return Double(number)
    }
}
