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
}


