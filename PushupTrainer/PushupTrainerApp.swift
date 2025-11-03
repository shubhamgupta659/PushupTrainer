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
        //TestDataGenerator.generateTestData()
        
        // Uncomment to clear all data and start fresh
        //TestDataGenerator.clearTestData()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
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
