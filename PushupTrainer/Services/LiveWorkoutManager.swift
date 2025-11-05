//
//  LiveWorkoutManager.swift
//  PushupTrainer
//
//  Modern HKLiveWorkoutBuilder implementation for iOS 17+
//

import Foundation
import HealthKit
import Combine

@available(iOS 17.0, *)
final class LiveWorkoutManager: NSObject, ObservableObject {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    @Published var currentHeartRate: Double?
    @Published var activeCalories: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var sessionState: HKWorkoutSessionState = .notStarted
    
    private var startDate: Date?
    
    override init() {
        super.init()
    }
    
    // MARK: - Public Interface
    
    func startWorkout() async throws {
        #if DEBUG
        print("[LiveWorkout] 🚀 Starting live workout with HKLiveWorkoutBuilder...")
        #endif
        
        // 1. Create workout configuration
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        
        #if DEBUG
        print("[LiveWorkout] ✅ Workout configuration created")
        #endif
        
        // 2. Create workout session
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        
        #if DEBUG
        print("[LiveWorkout] ✅ Workout session and builder created")
        #endif
        
        // 3. Set up data source for live data collection
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )
        
        #if DEBUG
        print("[LiveWorkout] ✅ Live data source configured")
        #endif
        
        // 4. Set delegates
        session.delegate = self
        builder.delegate = self
        
        self.workoutSession = session
        self.workoutBuilder = builder
        self.startDate = Date()
        
        // 5. Start session and collection
        session.startActivity(with: startDate!)
        try await builder.beginCollection(at: startDate!)
        
        #if DEBUG
        print("[LiveWorkout] ✅ Live workout started - waiting for heart rate data...")
        #endif
    }
    
    func pauseWorkout() {
        #if DEBUG
        print("[LiveWorkout] ⏸️ Pausing workout...")
        #endif
        workoutSession?.pause()
    }
    
    func resumeWorkout() {
        #if DEBUG
        print("[LiveWorkout] ▶️ Resuming workout...")
        #endif
        workoutSession?.resume()
    }
    
    func endWorkout() async throws -> HKWorkout? {
        #if DEBUG
        print("[LiveWorkout] 🛑 Ending workout...")
        #endif
        
        guard let builder = workoutBuilder, let session = workoutSession else {
            #if DEBUG
            print("[LiveWorkout] ❌ No active workout to end")
            #endif
            return nil
        }
        
        let endDate = Date()
        
        // 1. End session
        session.end()
        
        #if DEBUG
        print("[LiveWorkout] ✅ Session ended")
        #endif
        
        // 2. End collection
        try await builder.endCollection(at: endDate)
        
        #if DEBUG
        print("[LiveWorkout] ✅ Collection ended")
        #endif
        
        // 3. Finish and save workout
        let workout = try await builder.finishWorkout()
        
        #if DEBUG
        print("[LiveWorkout] ✅ Workout saved to HealthKit")
        if let workout = workout {
            print("[LiveWorkout] 📊 Duration: \(workout.duration)s")
            print("[LiveWorkout] 📊 Calories: \(workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)")
        } else {
            print("[LiveWorkout] ⚠️ Workout object is nil")
        }
        #endif
        
        // Clean up
        self.workoutSession = nil
        self.workoutBuilder = nil
        
        return workout
    }
    
    func cancelWorkout() async {
        #if DEBUG
        print("[LiveWorkout] ❌ Canceling workout...")
        #endif
        
        workoutSession?.end()
        
        // Clean up without saving
        self.workoutSession = nil
        self.workoutBuilder = nil
        self.currentHeartRate = nil
        self.activeCalories = 0
        self.elapsedTime = 0
    }
}

// MARK: - HKWorkoutSessionDelegate
@available(iOS 17.0, *)
extension LiveWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                       didChangeTo toState: HKWorkoutSessionState,
                       from fromState: HKWorkoutSessionState,
                       date: Date) {
        DispatchQueue.main.async {
            self.sessionState = toState
            
            #if DEBUG
            let stateString: String
            switch toState {
            case .notStarted: stateString = "notStarted"
            case .running: stateString = "running"
            case .paused: stateString = "paused"
            case .ended: stateString = "ended"
            case .stopped: stateString = "stopped"
            case .prepared: stateString = "prepared"
            @unknown default: stateString = "unknown"
            }
            print("[LiveWorkout] 📊 Session state changed: \(fromState.rawValue) → \(stateString)")
            #endif
            
            switch toState {
            case .running:
                #if DEBUG
                print("[LiveWorkout] ▶️ Workout is now running")
                #endif
            case .paused:
                #if DEBUG
                print("[LiveWorkout] ⏸️ Workout is now paused")
                #endif
            case .ended:
                #if DEBUG
                print("[LiveWorkout] 🛑 Workout session ended")
                #endif
            default:
                break
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                       didFailWithError error: Error) {
        #if DEBUG
        print("[LiveWorkout] ❌ Workout session failed: \(error.localizedDescription)")
        #endif
        
        DispatchQueue.main.async {
            self.workoutSession = nil
            self.workoutBuilder = nil
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                       didGenerate event: HKWorkoutEvent) {
        #if DEBUG
        print("[LiveWorkout] 📍 Workout event: \(event.type.rawValue)")
        #endif
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
@available(iOS 17.0, *)
extension LiveWorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                       didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // This is called automatically as live data comes in from Apple Watch or iPhone sensors
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            switch quantityType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                if let statistics = workoutBuilder.statistics(for: quantityType),
                   let heartRate = statistics.mostRecentQuantity() {
                    let bpm = heartRate.doubleValue(for: .count().unitDivided(by: .minute()))
                    DispatchQueue.main.async {
                        self.currentHeartRate = bpm
                        #if DEBUG
                        print("[LiveWorkout] 💓 Heart rate updated: \(Int(bpm)) bpm")
                        #endif
                    }
                }
                
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                if let statistics = workoutBuilder.statistics(for: quantityType),
                   let energy = statistics.sumQuantity() {
                    let calories = energy.doubleValue(for: .kilocalorie())
                    DispatchQueue.main.async {
                        self.activeCalories = calories
                        #if DEBUG
                        print("[LiveWorkout] 🔥 Calories updated: \(String(format: "%.1f", calories))")
                        #endif
                    }
                }
                
            default:
                break
            }
        }
        
        // Update elapsed time
        if let startDate = self.startDate {
            let elapsed = Date().timeIntervalSince(startDate)
            DispatchQueue.main.async {
                self.elapsedTime = elapsed
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        #if DEBUG
        print("[LiveWorkout] 📍 Builder collected event")
        #endif
    }
}

