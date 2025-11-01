//
//  TestDataGenerator.swift
//  PushupTrainer
//

import Foundation

enum TestDataGenerator {
    /// Generate test data for development/testing
    /// Call this from app initialization to populate with sample data
    static func generateTestData() {
        #if DEBUG
        print("[TestData] Generating test data...")
        
        let calendar = Calendar.current
        let now = Date()
        
        // Always create test profile (overwrite if exists)
        let onboardingDate = calendar.date(byAdding: .day, value: -365, to: now) ?? now
        let profile = UserProfile(
            id: UUID(),
            displayName: "Test User",
            gender: "Male",
            age: 28,
            heightCm: 175,
            weightKg: 75,
            targetReps: 100,
            currentMaxPushups: 20,
            units: Units(height: .cm, weight: .kg),
            avatarImageData: nil,
            defaultMode: .manual,
            createdAt: onboardingDate,
            updatedAt: now,
            onboardingDate: onboardingDate
        )
        ProfileStore.save(profile)
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        print("[TestData] Created test profile (onboarded 365 days ago)")
        
        // Always create test plan (overwrite if exists)
        var days: [PlanDay] = []
        let planStartDate = calendar.date(byAdding: .day, value: -90, to: now) ?? now
        
        for i in 1...90 {
            let targetReps = 20 + (i * 1) // Progressive: 21, 22, 23... up to 110
            let isCompleted = i <= 60 // Mark first 60 days as completed
            let completedDate = isCompleted ? calendar.date(byAdding: .day, value: i - 1, to: planStartDate) : nil
            
            days.append(PlanDay(
                id: UUID(),
                dayNumber: i,
                targetReps: targetReps,
                isCompleted: isCompleted,
                completedDate: completedDate
            ))
        }
        
        let plan = WorkoutPlan(
            id: UUID(),
            startDate: planStartDate,
            totalDays: 90,
            days: days,
            targetReps: 110,
            currentMax: 20
        )
        PlanStore.save(plan)
        print("[TestData] Created test plan with 90 days")
        
        // Always generate test sessions (overwrite if exists)
        var sessions: [WorkoutSession] = []
        
        // Generate FULL YEAR (365 days) of workout history
        print("[TestData] Generating 365 days of workout history...")
        for dayOffset in -365...0 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            // Skip some days randomly (simulate missed workouts) - 25% miss rate
            let skipChance = Int.random(in: 1...100)
            if skipChance > 75 { continue }
            
            // Randomize number of sessions per day (1-3)
            let sessionsPerDay = Int.random(in: 1...2)
            
            for sessionNum in 0..<sessionsPerDay {
                let hour = [6, 12, 18].randomElement() ?? 12 // Morning, noon, or evening
                let minute = Int.random(in: 0...59)
                guard let sessionDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) else { continue }
                
                // Progressive reps over the year (start low, end high)
                let progress = Double(dayOffset + 365) / 365.0 // 0.0 to 1.0
                let baseReps = Int(10.0 + (progress * 40.0)) // 10 to 50 reps over the year
                let reps = max(5, baseReps + Int.random(in: -5...10))
                let targetReps = reps + Int.random(in: 5...15)
                
                let duration = reps * 2 + Int.random(in: 10...30)
                let endTime = sessionDate.addingTimeInterval(TimeInterval(duration))
                
                // Generate rep timestamps
                var timestamps: [Date] = []
                for repIndex in 0..<reps {
                    let repTime = sessionDate.addingTimeInterval(TimeInterval(repIndex * 2))
                    timestamps.append(repTime)
                }
                
                let session = WorkoutSession(
                    id: UUID(),
                    date: sessionDate,
                    startTime: sessionDate,
                    endTime: endTime,
                    reps: reps,
                    durationSeconds: duration,
                    mode: [.manual, .timer].randomElement() ?? .manual,
                    caloriesBurned: Double(reps) * 0.5,
                    notes: "",
                    repsTimestamps: timestamps,
                    targetRepsAtStart: targetReps,
                    averageHeartRateBPM: Double.random(in: 110...150),
                    maxHeartRateBPM: Double.random(in: 150...180),
                    recoveryHeartRateDropBPM: Double.random(in: 15...35)
                )
                
                sessions.append(session)
            }
            
            // Print progress every 30 days
            if dayOffset % 30 == 0 {
                print("[TestData] Generated data up to \(-dayOffset) days ago...")
            }
        }
        
        SessionStore.save(sessions)
        print("[TestData] Created \(sessions.count) test workout sessions over 365 days!")
        print("[TestData] Test data generation complete!")
        #endif
    }
    
    /// Clear all test data
    static func clearTestData() {
        #if DEBUG
        SessionStore.save([])
        PlanStore.delete()
        UserDefaults.standard.removeObject(forKey: "userProfile")
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "planStyle")
        print("[TestData] All test data cleared")
        #endif
    }
}

