//
//  ImportWorkoutView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Import a strength workout by pasting the Strong app's shared text, or by
/// picking an exported `.txt` file.
struct ImportWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @State private var text = ""
    @State private var showFileImporter = false
    @State private var importError: String?

    private var parsed: ParsedWorkout? {
        StrongWorkoutParser.parse(text)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Button {
                            if let clip = UIPasteboard.general.string {
                                text = clip
                            }
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                        Spacer()
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Import file", systemImage: "folder")
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                } footer: {
                    Text("In the Strong app, share a workout and copy the text, or export it as a .txt file — then paste or import it here.")
                }

                Section("Workout text") {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .font(.system(.footnote, design: .monospaced))
                }

                if let parsed {
                    Section("Preview") {
                        LabeledContent("Title", value: parsed.title)
                        LabeledContent("Date", value: parsed.date.formatted(.dateTime.weekday().day().month().hour().minute()))
                        LabeledContent("Exercises", value: "\(parsed.exercises.count)")
                        LabeledContent("Sets", value: "\(parsed.setCount)")
                        ForEach(Array(parsed.exercises.enumerated()), id: \.offset) { _, ex in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name).font(.subheadline.weight(.medium))
                                Text(setPreview(ex))
                                    .font(.caption).foregroundStyle(.secondary)
                                if let notes = ex.notes {
                                    Text("Notes: \(notes)").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else if !text.isEmpty {
                    Section {
                        Label("Couldn't find any exercises in that text.", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Import Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { save() }
                        .disabled(parsed == nil)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.plainText, .text, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Import failed", isPresented: .constant(importError != nil)) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func setPreview(_ ex: ParsedExercise) -> String {
        ex.sets.map { set in
            if let w = set.weightKg, w > 0 {
                let weight = w.formatted(.number.precision(.fractionLength(0...1)))
                return "\(weight) kg × \(set.reps ?? 0)"
            }
            return "\(set.reps ?? 0) reps"
        }.joined(separator: ", ")
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                text = try String(contentsOf: url, encoding: .utf8)
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func save() {
        guard let parsed else { return }
        let workout = StrongWorkoutParser.insert(parsed, into: context)
        dismiss()
        router.openWorkout(workout)
    }
}
