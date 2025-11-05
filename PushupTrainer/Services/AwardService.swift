//
//  AwardService.swift
//  PushupTrainer
//

import Foundation

class AwardService {
    static let shared = AwardService()
    
    private init() {}
    
    // Define all awards
    func getAllAwards() -> [Award] {
        var awards: [Award] = []
        
        // Reps Milestones
        awards.append(contentsOf: [
            Award(id: "reps_100", category: .repsMilestone, title: "Century Club", description: "Complete 100 total pushups", iconName: "star.fill", threshold: 100, unlockedAt: nil, progress: 0),
            Award(id: "reps_500", category: .repsMilestone, title: "Half K", description: "Complete 500 total pushups", iconName: "star.circle.fill", threshold: 500, unlockedAt: nil, progress: 0),
            Award(id: "reps_1000", category: .repsMilestone, title: "Thousand Club", description: "Complete 1,000 total pushups", iconName: "medal.fill", threshold: 1000, unlockedAt: nil, progress: 0),
            Award(id: "reps_2500", category: .repsMilestone, title: "Elite Milestone", description: "Complete 2,500 total pushups", iconName: "seal.fill", threshold: 2500, unlockedAt: nil, progress: 0),
            Award(id: "reps_5000", category: .repsMilestone, title: "Legendary", description: "Complete 5,000 total pushups", iconName: "trophy.fill", threshold: 5000, unlockedAt: nil, progress: 0),
            Award(id: "reps_10000", category: .repsMilestone, title: "Master", description: "Complete 10,000 total pushups", iconName: "trophy.circle.fill", threshold: 10000, unlockedAt: nil, progress: 0),
            Award(id: "reps_25000", category: .repsMilestone, title: "Grandmaster", description: "Complete 25,000 total pushups", iconName: "crown.fill", threshold: 25000, unlockedAt: nil, progress: 0),
            Award(id: "reps_50000", category: .repsMilestone, title: "Immortal", description: "Complete 50,000 total pushups", iconName: "sparkles", threshold: 50000, unlockedAt: nil, progress: 0),
        ])
        
        // Workout Streaks
        awards.append(contentsOf: [
            Award(id: "streak_3", category: .workoutStreak, title: "Getting Started", description: "3 day streak", iconName: "flame.fill", threshold: 3, unlockedAt: nil, progress: 0),
            Award(id: "streak_7", category: .workoutStreak, title: "Week Warrior", description: "7 day streak", iconName: "flame.fill", threshold: 7, unlockedAt: nil, progress: 0),
            Award(id: "streak_14", category: .workoutStreak, title: "Two Week Champion", description: "14 day streak", iconName: "flame.fill", threshold: 14, unlockedAt: nil, progress: 0),
            Award(id: "streak_30", category: .workoutStreak, title: "Monthly Master", description: "30 day streak", iconName: "flame.fill", threshold: 30, unlockedAt: nil, progress: 0),
            Award(id: "streak_60", category: .workoutStreak, title: "Dedicated", description: "60 day streak", iconName: "flame.fill", threshold: 60, unlockedAt: nil, progress: 0),
            Award(id: "streak_100", category: .workoutStreak, title: "Centurion", description: "100 day streak", iconName: "flame.fill", threshold: 100, unlockedAt: nil, progress: 0),
            Award(id: "streak_365", category: .workoutStreak, title: "Year Warrior", description: "365 day streak", iconName: "flame.fill", threshold: 365, unlockedAt: nil, progress: 0),
        ])
        
        // Workout Count
        awards.append(contentsOf: [
            Award(id: "workouts_10", category: .workoutCount, title: "Getting Stronger", description: "Complete 10 workouts", iconName: "figure.strengthtraining.traditional", threshold: 10, unlockedAt: nil, progress: 0),
            Award(id: "workouts_25", category: .workoutCount, title: "Building Habit", description: "Complete 25 workouts", iconName: "figure.strengthtraining.traditional", threshold: 25, unlockedAt: nil, progress: 0),
            Award(id: "workouts_50", category: .workoutCount, title: "Consistent", description: "Complete 50 workouts", iconName: "figure.strengthtraining.traditional", threshold: 50, unlockedAt: nil, progress: 0),
            Award(id: "workouts_100", category: .workoutCount, title: "Century Workouts", description: "Complete 100 workouts", iconName: "figure.strengthtraining.traditional", threshold: 100, unlockedAt: nil, progress: 0),
            Award(id: "workouts_250", category: .workoutCount, title: "Dedicated Athlete", description: "Complete 250 workouts", iconName: "figure.strengthtraining.traditional", threshold: 250, unlockedAt: nil, progress: 0),
            Award(id: "workouts_500", category: .workoutCount, title: "Elite Athlete", description: "Complete 500 workouts", iconName: "figure.strengthtraining.traditional", threshold: 500, unlockedAt: nil, progress: 0),
            Award(id: "workouts_1000", category: .workoutCount, title: "Legendary Athlete", description: "Complete 1,000 workouts", iconName: "figure.strengthtraining.traditional", threshold: 1000, unlockedAt: nil, progress: 0),
        ])
        
        // Perfect Days
        awards.append(contentsOf: [
            Award(id: "perfect_7", category: .perfectDays, title: "Perfect Week", description: "7 days meeting target", iconName: "star.circle.fill", threshold: 7, unlockedAt: nil, progress: 0),
            Award(id: "perfect_14", category: .perfectDays, title: "Perfect Fortnight", description: "14 days meeting target", iconName: "star.circle.fill", threshold: 14, unlockedAt: nil, progress: 0),
            Award(id: "perfect_30", category: .perfectDays, title: "Perfect Month", description: "30 days meeting target", iconName: "star.circle.fill", threshold: 30, unlockedAt: nil, progress: 0),
            Award(id: "perfect_60", category: .perfectDays, title: "Perfect Champion", description: "60 days meeting target", iconName: "star.circle.fill", threshold: 60, unlockedAt: nil, progress: 0),
            Award(id: "perfect_100", category: .perfectDays, title: "Perfect Centurion", description: "100 days meeting target", iconName: "star.circle.fill", threshold: 100, unlockedAt: nil, progress: 0),
        ])
        
        // Personal Records
        awards.append(contentsOf: [
            Award(id: "pr_25", category: .personalRecord, title: "Breaking Limits", description: "25 reps in one workout", iconName: "trophy.fill", threshold: 25, unlockedAt: nil, progress: 0),
            Award(id: "pr_50", category: .personalRecord, title: "Half Century", description: "50 reps in one workout", iconName: "trophy.fill", threshold: 50, unlockedAt: nil, progress: 0),
            Award(id: "pr_75", category: .personalRecord, title: "Strong", description: "75 reps in one workout", iconName: "trophy.fill", threshold: 75, unlockedAt: nil, progress: 0),
            Award(id: "pr_100", category: .personalRecord, title: "Century Single", description: "100 reps in one workout", iconName: "trophy.fill", threshold: 100, unlockedAt: nil, progress: 0),
            Award(id: "pr_150", category: .personalRecord, title: "Elite", description: "150 reps in one workout", iconName: "trophy.fill", threshold: 150, unlockedAt: nil, progress: 0),
            Award(id: "pr_200", category: .personalRecord, title: "Legendary", description: "200 reps in one workout", iconName: "trophy.fill", threshold: 200, unlockedAt: nil, progress: 0),
            Award(id: "pr_300", category: .personalRecord, title: "Immortal", description: "300 reps in one workout", iconName: "trophy.fill", threshold: 300, unlockedAt: nil, progress: 0),
        ])
        
        // Calories
        awards.append(contentsOf: [
            Award(id: "calories_1000", category: .calories, title: "Calorie Starter", description: "Burn 1,000 calories", iconName: "bolt.fill", threshold: 1000, unlockedAt: nil, progress: 0),
            Award(id: "calories_5000", category: .calories, title: "Calorie Warrior", description: "Burn 5,000 calories", iconName: "bolt.fill", threshold: 5000, unlockedAt: nil, progress: 0),
            Award(id: "calories_10000", category: .calories, title: "Calorie Master", description: "Burn 10,000 calories", iconName: "bolt.fill", threshold: 10000, unlockedAt: nil, progress: 0),
            Award(id: "calories_25000", category: .calories, title: "Calorie Elite", description: "Burn 25,000 calories", iconName: "bolt.fill", threshold: 25000, unlockedAt: nil, progress: 0),
            Award(id: "calories_50000", category: .calories, title: "Calorie Legend", description: "Burn 50,000 calories", iconName: "bolt.fill", threshold: 50000, unlockedAt: nil, progress: 0),
            Award(id: "calories_100000", category: .calories, title: "Calorie Immortal", description: "Burn 100,000 calories", iconName: "bolt.fill", threshold: 100000, unlockedAt: nil, progress: 0),
        ])
        
        // Weekly Achievements
        awards.append(contentsOf: [
            Award(id: "weekly_500", category: .weeklyAchievement, title: "Weekly Warrior", description: "500 reps in a week", iconName: "calendar.badge.clock", threshold: 500, unlockedAt: nil, progress: 0),
            Award(id: "weekly_1000", category: .weeklyAchievement, title: "Weekly Elite", description: "1,000 reps in a week", iconName: "calendar.badge.clock", threshold: 1000, unlockedAt: nil, progress: 0),
            Award(id: "weekly_7days", category: .weeklyAchievement, title: "Perfect Week", description: "Workout all 7 days", iconName: "calendar.badge.clock", threshold: 7, unlockedAt: nil, progress: 0),
        ])
        
        // Monthly Achievements
        awards.append(contentsOf: [
            Award(id: "monthly_2000", category: .monthlyAchievement, title: "Monthly Warrior", description: "2,000 reps in a month", iconName: "calendar", threshold: 2000, unlockedAt: nil, progress: 0),
            Award(id: "monthly_5000", category: .monthlyAchievement, title: "Monthly Elite", description: "5,000 reps in a month", iconName: "calendar", threshold: 5000, unlockedAt: nil, progress: 0),
            Award(id: "monthly_30days", category: .monthlyAchievement, title: "Perfect Month", description: "Workout all 30 days", iconName: "calendar", threshold: 30, unlockedAt: nil, progress: 0),
        ])
        
        return awards
    }
    
    // Calculate user statistics
    func calculateStats() -> (totalReps: Int, totalWorkouts: Int, currentStreak: Int, longestStreak: Int, perfectDays: Int, maxRepsInSession: Int, totalCalories: Double) {
        let sessions = SessionStore.load()
        let profile = ProfileStore.load()
        let plan = PlanStore.load()
        
        // Total reps
        let totalReps = sessions.reduce(0) { $0 + $1.reps }
        
        // Total workouts
        let totalWorkouts = sessions.count
        
        // Calculate streaks
        let (currentStreak, longestStreak) = calculateStreaks(sessions: sessions, profile: profile)
        
        // Perfect days (days where target was met)
        let perfectDays = calculatePerfectDays(sessions: sessions, plan: plan, profile: profile)
        
        // Max reps in single session
        let maxRepsInSession = sessions.map { $0.reps }.max() ?? 0
        
        // Total calories
        let totalCalories = sessions.reduce(0.0) { $0 + $1.caloriesBurned }
        
        return (totalReps, totalWorkouts, currentStreak, longestStreak, perfectDays, maxRepsInSession, totalCalories)
    }
    
    private func calculateStreaks(sessions: [WorkoutSession], profile: UserProfile?) -> (current: Int, longest: Int) {
        guard !sessions.isEmpty else { return (0, 0) }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get unique workout dates
        let workoutDates = Set(sessions.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        
        guard !workoutDates.isEmpty else { return (0, 0) }
        
        // Filter out future dates and dates before onboarding
        let validDates: [Date]
        if let onboardingDate = profile?.onboardingDate {
            let onboardingStart = calendar.startOfDay(for: onboardingDate)
            validDates = workoutDates.filter { $0 <= today && $0 >= onboardingStart }
        } else {
            validDates = workoutDates.filter { $0 <= today }
        }
        
        guard !validDates.isEmpty else { return (0, 0) }
        
        // Calculate current streak
        var currentStreak = 0
        var expectedDate = today
        
        for date in validDates {
            if calendar.isDate(date, inSameDayAs: expectedDate) {
                currentStreak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else if date < expectedDate {
                break
            }
        }
        
        // Calculate longest streak
        var longestStreak = 0
        var tempStreak = 0
        var prevDate: Date?
        
        for date in validDates.sorted() {
            if let prev = prevDate {
                let daysDiff = calendar.dateComponents([.day], from: prev, to: date).day ?? 0
                if daysDiff == 1 {
                    tempStreak += 1
                } else {
                    longestStreak = max(longestStreak, tempStreak)
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            prevDate = date
        }
        longestStreak = max(longestStreak, tempStreak)
        
        return (currentStreak, longestStreak)
    }
    
    private func calculatePerfectDays(sessions: [WorkoutSession], plan: WorkoutPlan?, profile: UserProfile?) -> Int {
        let calendar = Calendar.current
        var perfectDays = 0
        
        // Group sessions by date
        var dailyReps: [Date: Int] = [:]
        var dailyTargets: [Date: Int] = [:]
        
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.date)
            dailyReps[dayStart, default: 0] += session.reps
            dailyTargets[dayStart, default: 0] += session.targetRepsAtStart ?? 0
        }
        
        // Check each day
        for (date, reps) in dailyReps {
            let targets = dailyTargets[date] ?? 0
            
            // Get target from plan if not captured
            let targetReps: Int
            if targets > 0 {
                targetReps = targets
            } else if let plan = plan {
                let planStart = calendar.startOfDay(for: plan.startDate)
                if let daysDiff = calendar.dateComponents([.day], from: planStart, to: date).day {
                    let dayNumber = daysDiff + 1
                    if let planDay = plan.days.first(where: { $0.dayNumber == dayNumber }) {
                        targetReps = planDay.targetReps
                    } else {
                        targetReps = plan.targetReps
                    }
                } else {
                    targetReps = plan.targetReps
                }
            } else {
                continue // Skip if no target available
            }
            
            if reps >= targetReps {
                perfectDays += 1
            }
        }
        
        return perfectDays
    }
    
    // Update awards with current progress
    func updateAwardsProgress() -> [Award] {
        let stats = calculateStats()
        let sessions = SessionStore.load()
        let progress = AwardStore.loadProgress()
        var awards = getAllAwards()
        
        // Calculate weekly and monthly stats
        let calendar = Calendar.current
        let now = Date()
        
        // Weekly stats
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 1 // Sunday
        guard let startOfWeek = calendar.date(from: comps) else { return awards }
        let weeklySessions = sessions.filter { $0.date >= startOfWeek }
        let weeklyReps = weeklySessions.reduce(0) { $0 + $1.reps }
        let weeklyDays = Set(weeklySessions.map { calendar.startOfDay(for: $0.date) }).count
        
        // Monthly stats
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return awards }
        let monthlySessions = sessions.filter { $0.date >= startOfMonth }
        let monthlyReps = monthlySessions.reduce(0) { $0 + $1.reps }
        let monthlyDays = Set(monthlySessions.map { calendar.startOfDay(for: $0.date) }).count
        
        // Update each award
        for i in 0..<awards.count {
            var award = awards[i]
            let wasUnlocked = progress.unlockedAwardIds.contains(award.id)
            
            switch award.category {
            case .repsMilestone:
                award.progress = min(1.0, Double(stats.totalReps) / Double(award.threshold))
                if !wasUnlocked && stats.totalReps >= award.threshold {
                    award.unlockedAt = Date()
                    AwardStore.markAwardUnlocked(award.id)
                } else if wasUnlocked {
                    award.unlockedAt = Date() // Keep existing unlock date
                }
                
            case .workoutStreak:
                // Use current streak for progress and unlocking
                award.progress = min(1.0, Double(stats.currentStreak) / Double(award.threshold))
                if !wasUnlocked && stats.currentStreak >= award.threshold {
                    award.unlockedAt = Date()
                    AwardStore.markAwardUnlocked(award.id)
                } else if wasUnlocked && award.unlockedAt == nil {
                    // Preserve unlock date if already unlocked but date not set
                    award.unlockedAt = Date()
                }
                
            case .workoutCount:
                award.progress = min(1.0, Double(stats.totalWorkouts) / Double(award.threshold))
                if !wasUnlocked && stats.totalWorkouts >= award.threshold {
                    award.unlockedAt = Date()
                    AwardStore.markAwardUnlocked(award.id)
                } else if wasUnlocked {
                    award.unlockedAt = Date()
                }
                
            case .perfectDays:
                award.progress = min(1.0, Double(stats.perfectDays) / Double(award.threshold))
                if !wasUnlocked && stats.perfectDays >= award.threshold {
                    award.unlockedAt = Date()
                    AwardStore.markAwardUnlocked(award.id)
                } else if wasUnlocked {
                    award.unlockedAt = Date()
                }
                
            case .personalRecord:
                award.progress = min(1.0, Double(stats.maxRepsInSession) / Double(award.threshold))
                if !wasUnlocked && stats.maxRepsInSession >= award.threshold {
                    award.unlockedAt = Date()
                    AwardStore.markAwardUnlocked(award.id)
                } else if wasUnlocked {
                    award.unlockedAt = Date()
                }
                
            case .calories:
                award.progress = min(1.0, stats.totalCalories / Double(award.threshold))
                if !wasUnlocked && stats.totalCalories >= Double(award.threshold) {
                    award.unlockedAt = Date()
                    AwardStore.markAwardUnlocked(award.id)
                } else if wasUnlocked {
                    award.unlockedAt = Date()
                }
                
            case .weeklyAchievement:
                if award.id == "weekly_7days" {
                    award.progress = min(1.0, Double(weeklyDays) / 7.0)
                    if !wasUnlocked && weeklyDays >= 7 {
                        award.unlockedAt = Date()
                        AwardStore.markAwardUnlocked(award.id)
                    } else if wasUnlocked {
                        award.unlockedAt = Date()
                    }
                } else {
                    award.progress = min(1.0, Double(weeklyReps) / Double(award.threshold))
                    if !wasUnlocked && weeklyReps >= award.threshold {
                        award.unlockedAt = Date()
                        AwardStore.markAwardUnlocked(award.id)
                    } else if wasUnlocked {
                        award.unlockedAt = Date()
                    }
                }
                
            case .monthlyAchievement:
                if award.id == "monthly_30days" {
                    award.progress = min(1.0, Double(monthlyDays) / 30.0)
                    if !wasUnlocked && monthlyDays >= 30 {
                        award.unlockedAt = Date()
                        AwardStore.markAwardUnlocked(award.id)
                    } else if wasUnlocked {
                        award.unlockedAt = Date()
                    }
                } else {
                    award.progress = min(1.0, Double(monthlyReps) / Double(award.threshold))
                    if !wasUnlocked && monthlyReps >= award.threshold {
                        award.unlockedAt = Date()
                        AwardStore.markAwardUnlocked(award.id)
                    } else if wasUnlocked {
                        award.unlockedAt = Date()
                    }
                }
            }
            
            awards[i] = award
        }
        
        return awards
    }
}

