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
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var themeManager: ThemeManager
    @State private var tintColor: Color = .blue
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            WorkoutView()
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
                .tag(1)

            NavigationStack {
                EditPlanView()
            }
            .tabItem { Label("Plan", systemImage: "list.bullet.clipboard") }
            .tag(2)

            CalendarView()
                .tabItem { Label("Activity", systemImage: "calendar") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        .tint(tintColor)
        .onAppear {
            tintColor = themeManager.accentColor.color
        }
        .onChange(of: themeManager.accentColor) { _, newColor in
            tintColor = newColor.color
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionsUpdated"))) { _ in
            if selectedTab == 1 { 
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateHome"))) { _ in
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateWorkout"))) { _ in
            selectedTab = 1
        }
    }
}


