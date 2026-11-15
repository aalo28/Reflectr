//
//  ExerciseDetailView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var allExercises: [Exercise]

    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                setsCard
                if let notes = exercise.logNotes, !notes.isEmpty {
                    logNotesCard(notes)
                }
                reflectionCard
                if !history.isEmpty {
                    historyCard
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(BackgroundGradient())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
    }

    // MARK: - Sets

    private var setsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Sets", systemImage: "list.number")
                    .font(.subheadline.bold())
                Spacer()
                if let date = exercise.workout?.date {
                    Text(date, format: .dateTime.day().month().year())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(Array(exercise.orderedSets.enumerated()), id: \.offset) { index, set in
                HStack {
                    Text("Set \(index + 1)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(set.shortLabel)
                        .font(.callout.weight(.medium))
                }
                if index != exercise.orderedSets.count - 1 { Divider() }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func logNotesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Logged note", systemImage: "note.text").font(.caption.bold()).foregroundStyle(.secondary)
            Text(notes).font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Reflection (editable, auto-saved)

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            editorField(
                title: "Try next time",
                icon: "flask",
                prompt: "e.g. add a set, slow the eccentric, +2.5 kg…",
                text: stringBinding(\.tryNextTime)
            )
            Divider()
            editorField(
                title: "What to look for next time",
                icon: "eye",
                prompt: "e.g. watch front-delt fatigue, keep elbows tucked…",
                text: stringBinding(\.lookFor)
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }

    private func editorField(title: String, icon: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(Color.accentColor)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.plain)
        }
    }

    // MARK: - History of this exercise

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Previous \(exercise.name.lowercased()) sessions", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.bold())

            ForEach(history) { past in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if let date = past.workout?.date {
                            Text(date, format: .dateTime.weekday(.abbreviated).day().month())
                                .font(.caption.bold())
                        }
                        Spacer()
                        Text(past.setSummary).font(.caption).foregroundStyle(.secondary)
                    }
                    if let t = past.tryNextTime, !t.isEmpty {
                        adviceLine("flask", "Tried: \(t)")
                    }
                    if let l = past.lookFor, !l.isEmpty {
                        adviceLine("eye", "Watch: \(l)")
                    }
                    if let n = past.logNotes, !n.isEmpty {
                        adviceLine("note.text", n)
                    }
                }
                .padding(.vertical, 6)
                if past.id != history.last?.id { Divider() }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func adviceLine(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon).font(.caption2).foregroundStyle(Color.accentColor).padding(.top, 2)
            Text(text).font(.footnote)
        }
    }

    // MARK: - Helpers

    private var history: [Exercise] {
        let name = exercise.name.lowercased()
        let cutoff = exercise.workout?.date ?? .now
        let matches = allExercises.filter { candidate in
            candidate.id != exercise.id
                && candidate.name.lowercased() == name
                && (candidate.workout?.date ?? .distantPast) < cutoff
        }
        return matches.sorted {
            ($0.workout?.date ?? .distantPast) < ($1.workout?.date ?? .distantPast)
        }
    }

    private func stringBinding(_ keyPath: ReferenceWritableKeyPath<Exercise, String?>) -> Binding<String> {
        Binding(
            get: { exercise[keyPath: keyPath] ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                exercise[keyPath: keyPath] = trimmed.isEmpty ? nil : newValue
            }
        )
    }
}
