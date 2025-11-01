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
        }
    }
}
