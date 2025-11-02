//
//  WorkoutSession.swift
//  PushupTrainer
//

import Foundation

enum WorkoutMode: String, Codable, CaseIterable, Identifiable {
    case manual, timer, voice
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .manual: return "Manual"
        case .timer: return "Timer"
        case .voice: return "Voice"
        }
    }
    
    var iconName: String {
        switch self {
        case .manual: return "hand.tap.fill"
        case .timer: return "timer"
        case .voice: return "waveform"
        }
    }
    
    var description: String {
        switch self {
        case .manual: return "Tap the circle to count each rep"
        case .timer: return "Auto-counts reps every 3 seconds"
        case .voice: return "Voice-activated rep counting"
        }
    }
}

struct WorkoutSession: Codable, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var startTime: Date
    var endTime: Date
    var reps: Int
    var durationSeconds: Int
    var mode: WorkoutMode
    var caloriesBurned: Double
    var notes: String
    var repsTimestamps: [Date]
    // Snapshot of the user's target reps at the moment the workout started
    // Optional for backward compatibility with older saved sessions
    var targetRepsAtStart: Int?
    // Health stats (optional, premium + HealthKit)
    var averageHeartRateBPM: Double?
    var maxHeartRateBPM: Double?
    // Recovery: drop in BPM over 60 seconds after workout end
    var recoveryHeartRateDropBPM: Double?
}

enum SessionStore {
    private static let key = "workoutSessions"

    static func load() -> [WorkoutSession] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([WorkoutSession].self, from: data)) ?? []
    }

    static func save(_ sessions: [WorkoutSession]) {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}


