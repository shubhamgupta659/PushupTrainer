//
//  RootView.swift
//  PushupTrainer
//

import SwiftUI

struct RootView: View {
    @StateObject private var themeManager = ThemeManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView(onFinish: { hasCompletedOnboarding = true })
            }
        }
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.theme.colorScheme)
        .animation(.easeInOut, value: themeManager.theme)
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            WorkoutView()
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
                .tag(1)

            CalendarView()
                .tabItem { Label("Activity", systemImage: "calendar") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionsUpdated"))) { _ in
            if selectedTab == 1 { selectedTab = 0 }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateHome"))) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateWorkout"))) { _ in
            selectedTab = 1
        }
    }
}


