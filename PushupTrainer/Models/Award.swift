//
//  Award.swift
//  PushupTrainer
//

import Foundation
import SwiftUI

enum AwardCategory: String, Codable, CaseIterable, Identifiable {
    case repsMilestone = "reps_milestone"
    case workoutStreak = "workout_streak"
    case workoutCount = "workout_count"
    case perfectDays = "perfect_days"
    case personalRecord = "personal_record"
    case calories = "calories"
    case weeklyAchievement = "weekly_achievement"
    case monthlyAchievement = "monthly_achievement"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .repsMilestone: return "Reps Milestones"
        case .workoutStreak: return "Streak Champions"
        case .workoutCount: return "Workout Warriors"
        case .perfectDays: return "Perfect Days"
        case .personalRecord: return "Personal Records"
        case .calories: return "Calorie Burners"
        case .weeklyAchievement: return "Weekly Achievements"
        case .monthlyAchievement: return "Monthly Achievements"
        }
    }
    
    var iconName: String {
        switch self {
        case .repsMilestone: return "number.circle.fill"
        case .workoutStreak: return "flame.fill"
        case .workoutCount: return "figure.strengthtraining.traditional"
        case .perfectDays: return "star.circle.fill"
        case .personalRecord: return "trophy.fill"
        case .calories: return "bolt.fill"
        case .weeklyAchievement: return "calendar.badge.clock"
        case .monthlyAchievement: return "calendar"
        }
    }
    
    var color: Color {
        switch self {
        case .repsMilestone: return .blue
        case .workoutStreak: return .orange
        case .workoutCount: return .purple
        case .perfectDays: return .yellow
        case .personalRecord: return .red
        case .calories: return .green
        case .weeklyAchievement: return .cyan
        case .monthlyAchievement: return .indigo
        }
    }
}

struct Award: Codable, Identifiable, Equatable {
    var id: String
    var category: AwardCategory
    var title: String
    var description: String
    var iconName: String
    var threshold: Int // The value needed to unlock (reps, days, workouts, etc.)
    var unlockedAt: Date?
    var progress: Double // 0.0 to 1.0
    
    var isUnlocked: Bool {
        unlockedAt != nil
    }
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
}

struct AwardProgress: Codable {
    var unlockedAwardIds: Set<String>
    var lastCheckedDate: Date
    
    init() {
        self.unlockedAwardIds = []
        self.lastCheckedDate = Date()
    }
}

enum AwardStore {
    private static let progressKey = "awardProgress"
    
    static func loadProgress() -> AwardProgress {
        guard let data = UserDefaults.standard.data(forKey: progressKey) else {
            return AwardProgress()
        }
        do {
            let progress = try JSONDecoder().decode(AwardProgress.self, from: data)
            return progress
        } catch {
            #if DEBUG
            print("[AwardStore] Failed to decode progress: \(error)")
            #endif
            return AwardProgress()
        }
    }
    
    static func saveProgress(_ progress: AwardProgress) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(progress)
            UserDefaults.standard.set(data, forKey: progressKey)
        } catch {
            #if DEBUG
            print("[AwardStore] Failed to encode progress: \(error)")
            #endif
        }
    }
    
    static func markAwardUnlocked(_ awardId: String) {
        var progress = loadProgress()
        progress.unlockedAwardIds.insert(awardId)
        progress.lastCheckedDate = Date()
        saveProgress(progress)
    }
    
    static func isAwardUnlocked(_ awardId: String) -> Bool {
        let progress = loadProgress()
        return progress.unlockedAwardIds.contains(awardId)
    }
}

