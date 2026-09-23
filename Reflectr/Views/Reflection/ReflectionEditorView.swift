//
//  ReflectionEditorView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

struct ReflectionEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let workout: Workout

    @State private var feeling: Int?
    @State private var energy: Int?
    @State private var rpe: Int?
    @State private var whatWentWell = ""
    @State private var whatWasntOptimal = ""
    @State private var keepInMind = ""
    @State private var tryNextTime = ""
    @State private var tags: [String] = []
    @State private var newTag = ""

    private let suggestedTags = ["poor sleep", "well fuelled", "great flow", "sore", "stressed", "strong", "tired legs", "hydrated"]

    var body: some View {
        NavigationStack {
            Form {
                Section("How did it feel?") {
                    RatingPicker(title: "Overall", systemImage: "face.smiling", range: 1...5, selection: $feeling)
                    RatingPicker(title: "Energy", systemImage: "bolt", range: 1...5, selection: $energy)
                    EffortSlider(rpe: $rpe)
                }

                Section {
                    LabeledField(label: "What went well", prompt: "Anything that clicked…", text: $whatWentWell)
                } header: {
                    Label("What went well", systemImage: "checkmark.seal")
                }

                Section {
                    LabeledField(label: "What wasn't optimal", prompt: "What felt off…", text: $whatWasntOptimal)
                } header: {
                    Label("What wasn't optimal", systemImage: "exclamationmark.triangle")
                }

                Section {
                    LabeledField(label: "Keep in mind", prompt: "For next similar session…", text: $keepInMind)
                } header: {
                    Label("Keep in mind next time", systemImage: "brain.head.profile")
                }

                Section {
                    LabeledField(label: "Try next time", prompt: "One thing to experiment with…", text: $tryNextTime)
                } header: {
                    Label("Try next time", systemImage: "flask")
                }

                Section("Tags") {
                    tagEditor
                }
            }
            .navigationTitle("Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                WrapTags(tags: tags) { tag in
                    tags.removeAll { $0 == tag }
                }
            }
            HStack {
                TextField("Add a tag", text: $newTag)
                    .textInputAutocapitalization(.never)
                    .onSubmit(addTypedTag)
                Button("Add", action: addTypedTag)
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            let remaining = suggestedTags.filter { !tags.contains($0) }
            if !remaining.isEmpty {
                WrapTags(tags: remaining, style: .suggestion) { tag in
                    if !tags.contains(tag) { tags.append(tag) }
                }
            }
        }
    }

    // MARK: - Logic

    private func addTypedTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { newTag = ""; return }
        tags.append(trimmed)
        newTag = ""
    }

    private func loadExisting() {
        guard let r = workout.reflection else { return }
        feeling = r.feeling
        energy = r.energy
        rpe = r.rpe
        whatWentWell = r.whatWentWell ?? ""
        whatWasntOptimal = r.whatWasntOptimal ?? ""
        keepInMind = r.keepInMind ?? ""
        tryNextTime = r.tryNextTime ?? ""
        tags = r.tags ?? []
    }

    private func save() {
        let reflection = workout.reflection ?? {
            let new = Reflection()
            context.insert(new)
            new.workout = workout
            workout.reflection = new
            return new
        }()

        reflection.feeling = feeling
        reflection.energy = energy
        reflection.rpe = rpe
        reflection.whatWentWell = trimmedOrNil(whatWentWell)
        reflection.whatWasntOptimal = trimmedOrNil(whatWasntOptimal)
        reflection.keepInMind = trimmedOrNil(keepInMind)
        reflection.tryNextTime = trimmedOrNil(tryNextTime)
        reflection.tags = tags.isEmpty ? nil : tags
        reflection.createdDate = .now

        try? context.save()
        dismiss()
    }

    private func trimmedOrNil(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Reusable pieces

private struct LabeledField: View {
    let label: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        TextField(prompt, text: $text, axis: .vertical)
            .lineLimit(2...6)
    }
}

struct RatingPicker: View {
    let title: String
    let systemImage: String
    let range: ClosedRange<Int>
    @Binding var selection: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
            HStack(spacing: 8) {
                ForEach(Array(range), id: \.self) { value in
                    Button {
                        selection = (selection == value) ? nil : value
                    } label: {
                        Text("\(value)")
                            .font(.callout.weight(.semibold))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle().fill(selection == value ? Color.accentColor : Color.gray.opacity(0.15))
                            )
                            .foregroundStyle(selection == value ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EffortSlider: View {
    @Binding var rpe: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Perceived effort", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.subheadline)
                Spacer()
                Text(rpe.map { "RPE \($0)" } ?? "—")
                    .font(.subheadline.bold())
                    .foregroundStyle(rpe == nil ? .secondary : Color.accentColor)
            }
            Slider(
                value: Binding(
                    get: { Double(rpe ?? 5) },
                    set: { rpe = Int($0.rounded()) }
                ),
                in: 1...10,
                step: 1
            )
        }
        .padding(.vertical, 4)
    }
}
