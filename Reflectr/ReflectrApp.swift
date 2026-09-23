//
//  ReflectrApp.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

@main
struct ReflectrApp: App {
    @AppStorage("isFirstLaunch") private var isFirstLaunch: Bool = true

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(ItemsContainer.create(shouldSeed: &isFirstLaunch))
    }
}
