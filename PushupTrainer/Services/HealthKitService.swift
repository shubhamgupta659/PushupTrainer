//
//  HealthKitService.swift
//  PushupTrainer
//

import Foundation
import HealthKit

final class HealthKitService {
    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?

    private init() {}

    var isHealthDataAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard isHealthDataAvailable else { completion(false); return }
        #if DEBUG
        print("[HealthKit] requestAuthorization called")
        #endif

        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(false)
            return
        }

        var typesToShare: Set<HKSampleType> = []
        // Allow writing workouts and active energy
        typesToShare.insert(HKObjectType.workoutType())
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            typesToShare.insert(energyType)
        }
        let typesToRead: Set<HKObjectType> = [hrType]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            #if DEBUG
            if let error { print("[HealthKit] authorization error: \(error.localizedDescription)") } else { print("[HealthKit] authorization success? \(success)") }
            #endif
            DispatchQueue.main.async { completion(success) }
        }
    }

    func startHeartRateStreaming(update: @escaping (_ bpm: Double) -> Void) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)

        let query = HKAnchoredObjectQuery(type: hrType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            self.handleHeartRate(samples: samples, update: update)
        }

        query.updateHandler = { _, samples, _, _, _ in
            self.handleHeartRate(samples: samples, update: update)
        }

        heartRateQuery = query
        healthStore.execute(query)
    }

    func stopHeartRateStreaming() {
        if let query = heartRateQuery { healthStore.stop(query) }
        heartRateQuery = nil
    }

    private func handleHeartRate(samples: [HKSample]?, update: (_ bpm: Double) -> Void) {
        guard let quantitySamples = samples as? [HKQuantitySample] else { return }
        for sample in quantitySamples {
            let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let bpm = sample.quantity.doubleValue(for: bpmUnit)
            update(bpm)
        }
    }

    func saveWorkout(session: WorkoutSession) {
        let energy = HKQuantity(unit: .kilocalorie(), doubleValue: session.caloriesBurned)
        let metadata: [String: Any] = [
            "mode": session.mode.rawValue,
            "reps": session.reps,
            "avgHR": session.averageHeartRateBPM ?? NSNull(),
            "maxHR": session.maxHeartRateBPM ?? NSNull(),
            "recoveryDrop": session.recoveryHeartRateDropBPM ?? NSNull()
        ]

        if #available(iOS 17.0, *) {
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: HKWorkoutConfiguration(), device: .local())
            builder.beginCollection(withStart: session.startTime) { _, _ in
                // Add energy sample
                if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                    let sample = HKQuantitySample(type: energyType, quantity: energy, start: session.startTime, end: session.endTime)
                    builder.add([sample]) { _, _ in }
                }
                builder.endCollection(withEnd: session.endTime) { _, _ in
                    // Attach metadata before finishing
                    builder.addMetadata(metadata) { _, _ in
                        builder.finishWorkout { _, _ in }
                    }
                }
            }
        } else {
            let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
            let workout = HKWorkout(activityType: .traditionalStrengthTraining,
                                    start: session.startTime,
                                    end: session.endTime,
                                    workoutEvents: nil,
                                    totalEnergyBurned: energy,
                                    totalDistance: nil,
                                    metadata: metadata)
            healthStore.save(workout) { [weak self] success, _ in
                guard let self else { return }
                if success {
                    let sample = HKQuantitySample(type: energyType, quantity: energy, start: session.startTime, end: session.endTime)
                    self.healthStore.add([sample], to: workout) { _, _ in }
                }
            }
        }
    }
}


