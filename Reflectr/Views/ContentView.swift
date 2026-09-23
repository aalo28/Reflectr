//
//  ContentView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabsView()
            .background(BackgroundGradient())
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Workout.self, Reflection.self, Exercise.self, ExerciseSet.self, Settings.self], inMemory: true)
        .environment(AppRouter())
        .environment(HealthKitManager())
        .environment(Settings())
}
