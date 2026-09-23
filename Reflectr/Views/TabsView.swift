//
//  TabsView.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI
import SwiftData

struct TabsView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab(value: MyTabs.briefing) {
                BriefingView()
            } label: {
                Label("Briefing", systemImage: "sparkles")
            }

            Tab(value: MyTabs.calendar) {
                CalendarView()
            } label: {
                Label("Calendar", systemImage: "calendar")
            }

            Tab(value: MyTabs.plan) {
                PlanView()
            } label: {
                Label("Plan", systemImage: "list.bullet.clipboard")
            }

            Tab(value: MyTabs.review) {
                ReviewView()
            } label: {
                Label("Review", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
    }
}
