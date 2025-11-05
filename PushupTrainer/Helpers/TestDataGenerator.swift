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
        
        // Generate data to unlock ALL awards:
        // - Total reps: 50,000+ (highest: 50,000)
        // - Total workouts: 1,000+ (highest: 1,000)
        // - Current streak: 365+ days (highest: 365)
        // - Perfect days: 100+ (highest: 100)
        // - Max reps in session: 300+ (highest: 300)
        // - Total calories: 100,000+ (highest: 100,000)
        // - Weekly: 1,000 reps, 7 days
        // - Monthly: 5,000 reps, 30 days
        
        print("[TestData] Generating workout history to unlock ALL awards...")
        
        // Generate 400 days of consecutive workouts (365+ day streak)
        let totalDays = 400
        let totalRepsNeeded = 50000
        let workoutsNeeded = 1000
        
        // Calculate sessions per day to reach 1,000 workouts
        let sessionsPerDay = max(1, workoutsNeeded / totalDays)
        let actualSessionsPerDay = min(3, sessionsPerDay) // Cap at 3 sessions per day
        
        var totalRepsGenerated = 0
        var sessionCount = 0
        
        for dayOffset in -totalDays...0 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            
            // Ensure we have at least 1 session per day for streak
            let sessionsToday = actualSessionsPerDay
            
            for sessionIndex in 0..<sessionsToday {
                let hour = [6, 12, 18].randomElement() ?? 12
                let minute = Int.random(in: 0...59)
                guard let sessionDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) else { continue }
                
                // Calculate reps to distribute evenly to reach 50,000 total
                let remainingDays = totalDays + dayOffset
                let remainingSessions = (remainingDays * sessionsToday) + (sessionsToday - sessionIndex)
                let repsNeeded = max(50, (totalRepsNeeded - totalRepsGenerated) / max(1, remainingSessions))
                
                // Vary reps but ensure we meet targets
                let baseReps = repsNeeded
                let reps = max(50, baseReps + Int.random(in: -10...20))
                
                // Ensure at least one session has 300+ reps (for PR award)
                let finalReps: Int
                if dayOffset == -200 && sessionIndex == 0 {
                    finalReps = 350 // One session with 350 reps
                } else {
                    finalReps = reps
                }
                
                totalRepsGenerated += finalReps
                sessionCount += 1
                
                let targetReps = finalReps + Int.random(in: 0...10) // Always meet or exceed target
                let duration = finalReps * 2 + Int.random(in: 10...30)
                let endTime = sessionDate.addingTimeInterval(TimeInterval(duration))
                
                // Generate rep timestamps
                var timestamps: [Date] = []
                for repIndex in 0..<finalReps {
                    let repTime = sessionDate.addingTimeInterval(TimeInterval(repIndex * 2))
                    timestamps.append(repTime)
                }
                
                // Higher calories to reach 100,000+ total
                let calories = Double(finalReps) * 1.0 // 1 calorie per rep
                
                let session = WorkoutSession(
                    id: UUID(),
                    date: sessionDate,
                    startTime: sessionDate,
                    endTime: endTime,
                    reps: finalReps,
                    durationSeconds: duration,
                    mode: [.manual, .timer].randomElement() ?? .manual,
                    caloriesBurned: calories,
                    notes: "",
                    repsTimestamps: timestamps,
                    targetRepsAtStart: targetReps,
                    averageHeartRateBPM: Double.random(in: 110...150),
                    maxHeartRateBPM: Double.random(in: 150...180),
                    recoveryHeartRateDropBPM: Double.random(in: 15...35)
                )
                
                sessions.append(session)
            }
            
            // Print progress every 50 days
            if dayOffset % 50 == 0 {
                print("[TestData] Generated data up to \(-dayOffset) days ago... (\(sessionCount) sessions, \(totalRepsGenerated) reps)")
            }
        }
        
        SessionStore.save(sessions)
        print("[TestData] Created \(sessions.count) test workout sessions!")
        print("[TestData] Total reps: \(totalRepsGenerated), Total calories: \(Int(sessions.reduce(0) { $0 + $1.caloriesBurned }))")
        
        // Unlock ALL awards explicitly
        print("[TestData] Unlocking all awards...")
        let allAwards = AwardService.shared.getAllAwards()
        for award in allAwards {
            AwardStore.markAwardUnlocked(award.id)
        }
        print("[TestData] All \(allAwards.count) awards unlocked!")
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

