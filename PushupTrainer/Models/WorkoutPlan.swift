//
//  WorkoutPlan.swift
//  PushupTrainer
//

import Foundation

struct PlanDay: Codable, Identifiable, Equatable {
    var id: UUID
    var dayNumber: Int
    var targetReps: Int
    var isCompleted: Bool
    var completedDate: Date?
}

struct WorkoutPlan: Codable, Equatable {
    var id: UUID
    var startDate: Date
    var totalDays: Int
    var days: [PlanDay]
    var targetReps: Int
    var currentMax: Int
}

enum PlanStore {
    private static let key = "workoutPlan"

    static func load() -> WorkoutPlan? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WorkoutPlan.self, from: data)
    }

    static func save(_ plan: WorkoutPlan) {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func delete() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

enum PlanGenerator {
    static func generate(targetReps: Int, currentMax: Int, age: Int, bmi: Double) -> WorkoutPlan {
        let totalDays = calculatePlanDays(currentMax: currentMax, target: targetReps, age: age, bmi: bmi)
        var days: [PlanDay] = []
        let increment = Double(targetReps - currentMax) / Double(totalDays)

        for i in 1...totalDays {
            let dayReps = max(currentMax, Int(ceil(Double(currentMax) + increment * Double(i))))
            days.append(PlanDay(
                id: UUID(),
                dayNumber: i,
                targetReps: min(dayReps, targetReps),
                isCompleted: false,
                completedDate: nil
            ))
        }

        return WorkoutPlan(
            id: UUID(),
            startDate: Date(),
            totalDays: totalDays,
            days: days,
            targetReps: targetReps,
            currentMax: currentMax
        )
    }

    private static func calculatePlanDays(currentMax: Int, target: Int, age: Int, bmi: Double) -> Int {
        let diff = Double(target - currentMax)
        guard diff > 0 else { return 14 }
        var baseDays = Int(diff / 2.0)
        if baseDays < 7 { baseDays = 7 }
        if baseDays > 90 { baseDays = 90 }
        let ageFactor = age > 50 ? 1.3 : 1.0
        let bmiFactor = bmi > 30 ? 1.2 : (bmi < 18.5 ? 0.9 : 1.0)
        return Int(Double(baseDays) * ageFactor * bmiFactor)
    }
}

