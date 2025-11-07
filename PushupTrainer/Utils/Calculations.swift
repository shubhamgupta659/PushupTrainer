//
//  Calculations.swift
//  PushupTrainer
//

import Foundation

enum MET: Double { case gentle = 3.8, moderate = 5.0, vigorous = 8.0 }

enum Calculations {
    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let m = heightCm / 100.0
        guard m > 0 else { return 0 }
        return weightKg / (m * m)
    }

    static func calories(met: MET, weightKg: Double, durationSeconds: Int) -> Double {
        let hours = Double(durationSeconds) / 3600.0
        return met.rawValue * weightKg * hours
    }
    
    static func pushupCalories(reps: Int, durationSeconds: Int, weightKg: Double) -> Double {
        guard weightKg > 0 else { return 0 }
        let seconds = max(durationSeconds, 1)
        let minutes = max(Double(seconds) / 60.0, 0.1)
        let repsPerMinute = minutes > 0 ? Double(reps) / minutes : 0
        let met: MET
        switch repsPerMinute {
        case ..<10:
            met = .gentle
        case ..<20:
            met = .moderate
        default:
            met = .vigorous
        }
        let metCalories = calories(met: met, weightKg: weightKg, durationSeconds: seconds)
        let repCalories = Double(reps) * 0.3 // Approx 0.3 kcal per push-up
        let blended = metCalories * 0.6 + repCalories * 0.4
        return max(0, blended)
    }
}


