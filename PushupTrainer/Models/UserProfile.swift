//
//  UserProfile.swift
//  PushupTrainer
//

import Foundation

struct Units: Codable, Equatable {
    enum HeightUnit: String, Codable { case cm, ft }
    enum WeightUnit: String, Codable { case kg, lb }
    var height: HeightUnit
    var weight: WeightUnit
}

struct UserProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String?
    var gender: String
    var age: Int
    var heightCm: Double
    var weightKg: Double
    var targetReps: Int
    var currentMaxPushups: Int
    var units: Units
    var avatarImageData: Data?
    var defaultMode: WorkoutMode? // user preference for workout mode
    var createdAt: Date
    var updatedAt: Date
}

enum ProfileStore {
    private static let key = "userProfile"

    static func load() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    static func save(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}


