//
//  RootView.swift
//  PushupTrainer
//

import SwiftUI

struct RootView: View {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var iCloudSync = iCloudSyncService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("hasCheckediCloudRestore") private var hasCheckediCloudRestore: Bool = false
    
    @State private var showICloudRestore: Bool = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else if showICloudRestore && !hasCheckediCloudRestore {
                iCloudRestoreView(
                    onRestore: {
                        hasCompletedOnboarding = true
                        hasCheckediCloudRestore = true
                    },
                    onStartFresh: {
                        showICloudRestore = false
                        hasCheckediCloudRestore = true
                    }
                )
            } else {
                OnboardingView(onFinish: { hasCompletedOnboarding = true })
            }
        }
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.theme.colorScheme)
        .task {
            // Check if we should show iCloud restore
            if !hasCompletedOnboarding && !hasCheckediCloudRestore && iCloudSyncService.isAvailable() {
                let store = NSUbiquitousKeyValueStore.default
                let hasData = store.object(forKey: "icloud_profile") != nil ||
                              store.object(forKey: "icloud_sessions") != nil ||
                              store.object(forKey: "icloud_plan") != nil
                
                #if DEBUG
                print("[RootView] iCloud available: \(iCloudSyncService.isAvailable()), has data: \(hasData)")
                #endif
                
                showICloudRestore = hasData
            }
        }
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

            AwardsView()
                .tabItem { Label("Awards", systemImage: "trophy.fill") }
                .tag(2)

            CalendarView()
                .tabItem { Label("Activity", systemImage: "calendar") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        .tint(tintColor)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToTab"))) { notification in
            if let tabIndex = notification.object as? Int {
                withAnimation {
                    selectedTab = tabIndex
                }
            }
        }
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


