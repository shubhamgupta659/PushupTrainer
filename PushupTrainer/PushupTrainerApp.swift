//
//  PushupTrainerApp.swift
//  PushupTrainer
//
//  Created by Shubham Gupta on 10/29/25.
//

import SwiftUI
import Combine

@main
struct PushupTrainerApp: App {
    @StateObject private var iCloudSync = iCloudSyncService.shared
    
    init() {
        // Set default theme to system on first launch
        if UserDefaults.standard.object(forKey: "appTheme") == nil {
            UserDefaults.standard.set("system", forKey: "appTheme")
        }
        
        // Set default accent to blue on first launch
        if UserDefaults.standard.object(forKey: "accentColor") == nil {
            UserDefaults.standard.set("Blue", forKey: "accentColor")
        }
        
        // Generate test data on app launch (DEBUG only)
        #if DEBUG
        // Uncomment the line below to generate test data
        // TestDataGenerator.generateTestData()
        
        // Uncomment to clear all data and start fresh
        // TestDataGenerator.clearTestData()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(iCloudSync)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .task {
                    await performInitialiCloudSync()
                }
        }
    }
    
    private func performInitialiCloudSync() async {
        // Check if iCloud sync is enabled
        let isEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        
        guard isEnabled && iCloudSyncService.isAvailable() else {
            #if DEBUG
            print("[PushupTrainerApp] iCloud sync not enabled or unavailable")
            #endif
            return
        }
        
        #if DEBUG
        print("[PushupTrainerApp] 🔄 Performing initial iCloud sync on app launch...")
        #endif
        
        do {
            // First merge any data from iCloud
            try await iCloudSync.mergeFromiCloud()
            
            // Then sync local data to iCloud
            try await iCloudSync.syncAll()
        } catch {
            #if DEBUG
            print("[PushupTrainerApp] Error during initial iCloud sync: \(error)")
            #endif
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "pushuptrainer" else { return }
        
        switch url.host {
        case "home":
            // Navigate to home tab
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToTab"), object: 0)
        case "workout":
            // Navigate to workout tab
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToTab"), object: 1)
        case "activity":
            // Navigate to activity tab
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToTab"), object: 3)
        default:
            break
        }
    }
}
