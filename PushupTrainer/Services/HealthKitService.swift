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
    
    /// Check if HKLiveWorkoutBuilder is available (iOS 17+)
    var isLiveWorkoutBuilderAvailable: Bool {
        if #available(iOS 17.0, *) {
            return true
        }
        return false
    }
    
    func checkAuthorizationStatus() -> (read: Bool, write: Bool) {
        guard isHealthDataAvailable else { return (false, false) }
        
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return (false, false)
        }
        
        let workoutType = HKObjectType.workoutType()
        
        let hrStatus = healthStore.authorizationStatus(for: hrType)
        let workoutStatus = healthStore.authorizationStatus(for: workoutType)
        let energyStatus = healthStore.authorizationStatus(for: energyType)
        
        #if DEBUG
        var hrStatusString: String
        switch hrStatus {
        case .notDetermined: hrStatusString = "notDetermined"
        case .sharingDenied: hrStatusString = "sharingDenied"
        case .sharingAuthorized: hrStatusString = "sharingAuthorized"
        @unknown default: hrStatusString = "unknown(\(hrStatus.rawValue))"
        }
        
        var workoutStatusString: String
        switch workoutStatus {
        case .notDetermined: workoutStatusString = "notDetermined"
        case .sharingDenied: workoutStatusString = "sharingDenied"
        case .sharingAuthorized: workoutStatusString = "sharingAuthorized"
        @unknown default: workoutStatusString = "unknown(\(workoutStatus.rawValue))"
        }
        
        var energyStatusString: String
        switch energyStatus {
        case .notDetermined: energyStatusString = "notDetermined"
        case .sharingDenied: energyStatusString = "sharingDenied"
        case .sharingAuthorized: energyStatusString = "sharingAuthorized"
        @unknown default: energyStatusString = "unknown(\(energyStatus.rawValue))"
        }
        
        print("[HealthKit] 📊 checkAuthorizationStatus detailed:")
        print("[HealthKit]   - Heart Rate (read): \(hrStatusString)")
        print("[HealthKit]   - Workout Type (write): \(workoutStatusString)")
        print("[HealthKit]   - Active Energy (write): \(energyStatusString)")
        
        // IMPORTANT: authorizationStatus can be cached/stale when permissions are changed in Settings
        // If read is denied but write is authorized, try a test query to verify actual access
        if hrStatus == .sharingDenied && workoutStatus == .sharingAuthorized {
            print("[HealthKit] ⚠️ Mismatch detected: Read denied but Write authorized")
            print("[HealthKit] 💡 This suggests HealthKit cache might be stale")
            print("[HealthKit] 🔍 Attempting test query to verify actual read access...")
        }
        #endif
        
        let readAuthorized = hrStatus == .sharingAuthorized
        let writeAuthorized = workoutStatus == .sharingAuthorized && energyStatus == .sharingAuthorized
        
        #if DEBUG
        print("[HealthKit] 📊 Final result - Read: \(readAuthorized), Write: \(writeAuthorized)")
        #endif
        
        return (readAuthorized, writeAuthorized)
    }
    
    /// Test if we can actually read heart rate data (more reliable than authorizationStatus)
    func testHeartRateReadAccess(completion: @escaping (Bool) -> Void) {
        print("[HealthKit] 🧪 testHeartRateReadAccess function CALLED")
        #if DEBUG
        print("[HealthKit] 🧪 testHeartRateReadAccess function entered")
        #endif

        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            #if DEBUG
            print("[HealthKit] 🧪 Test query: hrType is nil")
            #endif
            completion(false)
            return
        }

        #if DEBUG
        print("[HealthKit] 🧪 Test query: Starting query execution...")
        #endif

        // Try to query for the most recent heart rate sample
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: hrType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            #if DEBUG
            print("[HealthKit] 🧪 Test query: Completion handler called")
            print("[HealthKit] 🧪 Test query: Samples count: \(samples?.count ?? 0)")
            if let error = error {
                print("[HealthKit] 🧪 Test query: Error details - domain: \((error as NSError).domain), code: \((error as NSError).code)")
            }
            #endif

            if let error = error {
                #if DEBUG
                print("[HealthKit] 🧪 Test query error: \(error.localizedDescription)")
                #endif
                // Check if it's an authorization error
                let nsError = error as NSError
                if nsError.domain == "com.apple.healthkit" && nsError.code == 4 {
                    // Error code 4 = authorization denied
                    #if DEBUG
                    print("[HealthKit] 🧪 Test query confirms: Read access DENIED")
                    #endif
                    completion(false)
                } else {
                    // Other error - might still have access
                    #if DEBUG
                    print("[HealthKit] 🧪 Test query: Other error (might have access)")
                    #endif
                    completion(true) // Assume we have access if it's not an auth error
                }
            } else {
                #if DEBUG
                print("[HealthKit] 🧪 Test query: Can read heart rate data! Access granted.")
                #endif
                completion(true)
            }
        }

        #if DEBUG
        print("[HealthKit] 🧪 Test query: Calling healthStore.execute(query)")
        #endif
        healthStore.execute(query)

        // Add a timeout in case the query never completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            #if DEBUG
            print("[HealthKit] 🧪 Test query: Timeout reached after 5s - assuming access denied")
            #endif
            completion(false)
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard isHealthDataAvailable else {
            #if DEBUG
            print("[HealthKit] ❌ Health data not available on this device")
            #endif
            DispatchQueue.main.async { completion(false) }
            return
        }
        #if DEBUG
        print("[HealthKit] 🔐 requestAuthorization called")
        print("[HealthKit] 🔍 Current thread: \(Thread.isMainThread ? "main" : "background")")
        #endif

        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            #if DEBUG
            print("[HealthKit] ❌ Heart rate type identifier not available")
            #endif
            DispatchQueue.main.async { completion(false) }
            return
        }
        
        // Check current authorization status before requesting
        let currentStatus = healthStore.authorizationStatus(for: hrType)
        #if DEBUG
        let statusString: String
        switch currentStatus {
        case .notDetermined: statusString = "notDetermined"
        case .sharingDenied: statusString = "sharingDenied"
        case .sharingAuthorized: statusString = "sharingAuthorized"
        @unknown default: statusString = "unknown(\(currentStatus.rawValue))"
        }
        print("[HealthKit] 🔍 Current authorization status BEFORE request: \(statusString)")
        #endif

        var typesToShare: Set<HKSampleType> = []
        // Allow writing workouts and active energy
        typesToShare.insert(HKObjectType.workoutType())
        if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            typesToShare.insert(energyType)
        }
        let typesToRead: Set<HKObjectType> = [hrType]
        
        #if DEBUG
        print("[HealthKit] 📝 Requesting authorization:")
        print("[HealthKit]   - Read: Heart Rate")
        print("[HealthKit]   - Write: Workout Type, Active Energy Burned")
        print("[HealthKit] 📞 Calling healthStore.requestAuthorization...")
        #endif

        // Request authorization - must be called from main thread per Apple guidelines
        DispatchQueue.main.async {
            self.healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
                #if DEBUG
                print("[HealthKit] 📞 Authorization callback invoked")
                print("[HealthKit]   - Success: \(success)")
                print("[HealthKit]   - Callback thread: \(Thread.isMainThread ? "main" : "background")")
                if let error = error {
                    print("[HealthKit]   - Error: \(error.localizedDescription)")
                    print("[HealthKit]   - Error domain: \((error as NSError).domain)")
                    print("[HealthKit]   - Error code: \((error as NSError).code)")
                } else {
                    print("[HealthKit]   - No error")
                }
                #endif
                
                // Wait a moment for HealthKit to update its internal state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Check actual authorization status after the callback
                    guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
                        DispatchQueue.main.async { completion(false) }
                        return
                    }
                    
                    let actualStatus = self.healthStore.authorizationStatus(for: hrType)
                    #if DEBUG
                    let statusString: String
                    switch actualStatus {
                    case .notDetermined: statusString = "notDetermined"
                    case .sharingDenied: statusString = "sharingDenied"
                    case .sharingAuthorized: statusString = "sharingAuthorized"
                    @unknown default: statusString = "unknown(\(actualStatus.rawValue))"
                    }
                    print("[HealthKit]   - Actual authorization status after callback: \(statusString)")
                    
                    // Also check write permissions
                    let workoutType = HKObjectType.workoutType()
                    let workoutStatus = self.healthStore.authorizationStatus(for: workoutType)
                    let workoutStatusString: String
                    switch workoutStatus {
                    case .notDetermined: workoutStatusString = "notDetermined"
                    case .sharingDenied: workoutStatusString = "sharingDenied"
                    case .sharingAuthorized: workoutStatusString = "sharingAuthorized"
                    @unknown default: workoutStatusString = "unknown(\(workoutStatus.rawValue))"
                    }
                    print("[HealthKit]   - Workout Type (write) status: \(workoutStatusString)")
                    #endif
                    
                    // Note: Even if success is false, we might still have authorization
                    // The callback success parameter can be misleading
                    let isAuthorized = actualStatus == .sharingAuthorized
                    
                    #if DEBUG
                    if let error = error {
                        print("[HealthKit] ❌ Authorization error: \(error.localizedDescription)")
                    } else {
                        print("[HealthKit] ✅ Authorization callback completed - Status: \(isAuthorized ? "authorized" : "not authorized")")
                        if actualStatus == .sharingDenied {
                            print("[HealthKit] ⚠️ HealthKit authorization was denied. User needs to enable it in Settings > Privacy & Security > Health > PushupTrainer")
                            print("[HealthKit] 💡 If you just enabled permissions in Settings, please restart the app completely")
                        }
                    }
                    #endif
                    
                    DispatchQueue.main.async { completion(isAuthorized) }
                }
            }
            
            #if DEBUG
            print("[HealthKit] ✅ requestAuthorization call dispatched, waiting for callback...")
            print("[HealthKit] ⏱️ 5 second timeout started - if callback doesn't fire, HealthKit capability is likely missing")
            #endif
        }
    }

    func startHeartRateStreaming(update: @escaping (_ bpm: Double) -> Void) {
        #if DEBUG
        print("[HealthKit] 🚀 startHeartRateStreaming called")
        #endif
        
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            #if DEBUG
            print("[HealthKit] ❌ Heart rate type not available")
            #endif
            return
        }
        
        // Check authorization status BEFORE requesting
        let authStatus = healthStore.authorizationStatus(for: hrType)
        #if DEBUG
        let statusString: String
        switch authStatus {
        case .notDetermined: statusString = "notDetermined"
        case .sharingDenied: statusString = "sharingDenied"
        case .sharingAuthorized: statusString = "sharingAuthorized"
        @unknown default: statusString = "unknown(\(authStatus.rawValue))"
        }
        print("[HealthKit] 🔐 Heart rate authorization status: \(statusString)")
        #endif
        
        // If authorization is denied, DO NOT proceed
        if authStatus == .sharingDenied {
            #if DEBUG
            print("[HealthKit] ❌ Heart rate authorization is DENIED")
            print("[HealthKit] 📱 User must enable Heart Rate in: Settings > Privacy & Security > Health > PushupTrainer")
            print("[HealthKit] 💡 After enabling, RESTART THE APP completely (force quit and relaunch)")
            print("[HealthKit] ⚠️ Cannot start heart rate streaming without authorization")
            #endif
            
            // Try requesting one more time in case the system state has changed
            requestAuthorization { [weak self] granted in
                guard let self = self else { return }
                
                if granted {
                    #if DEBUG
                    print("[HealthKit] ✅ Authorization granted on retry, starting streaming")
                    #endif
                    self.startHeartRateStreaming(update: update)
                } else {
                    #if DEBUG
                    print("[HealthKit] ❌ Authorization still denied after retry")
                    #endif
                }
            }
            return
        }
        
        // Request authorization if not determined
        if authStatus == .notDetermined {
            #if DEBUG
            print("[HealthKit] ⚠️ Heart rate authorization not determined, requesting authorization...")
            #endif
            
            requestAuthorization { [weak self] granted in
                #if DEBUG
                print("[HealthKit] 📞 Authorization callback in startHeartRateStreaming: \(granted)")
                #endif
                
                // Check status again after callback
                guard let self = self, let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
                let newStatus = self.healthStore.authorizationStatus(for: hrType)
                #if DEBUG
                var newStatusString: String
                switch newStatus {
                case .notDetermined: newStatusString = "notDetermined"
                case .sharingDenied: newStatusString = "sharingDenied"
                case .sharingAuthorized: newStatusString = "sharingAuthorized"
                @unknown default: newStatusString = "unknown(\(newStatus.rawValue))"
                }
                print("[HealthKit] 🔐 Authorization status AFTER callback: \(newStatusString)")
                #endif
                
                if newStatus == .sharingAuthorized {
                    #if DEBUG
                    print("[HealthKit] ✅ Authorization granted, starting heart rate streaming")
                    #endif
                    self.proceedWithHeartRateStreaming(hrType: hrType, update: update)
                } else {
                    #if DEBUG
                    print("[HealthKit] ❌ Authorization not granted (status: \(newStatusString))")
                    if newStatus == .sharingDenied {
                        print("[HealthKit] 📱 User must enable Heart Rate in Settings > Privacy & Security > Health > PushupTrainer")
                    }
                    #endif
                }
            }
            return
        }
        
        // Authorization is granted - proceed with query
        if authStatus == .sharingAuthorized {
            proceedWithHeartRateStreaming(hrType: hrType, update: update)
        }
    }
    
    /// Proceed with heart rate streaming (extracted for reuse)
    private func proceedWithHeartRateStreaming(hrType: HKQuantityType, update: @escaping (Double) -> Void) {
        #if DEBUG
        print("[HealthKit] ✅ Authorization confirmed, proceeding with heart rate query")
        #endif

        // Stop any existing query
        if let existingQuery = heartRateQuery {
            #if DEBUG
            print("[HealthKit] 🛑 Stopping existing heart rate query")
            #endif
            healthStore.stop(existingQuery)
            heartRateQuery = nil
        }

        // Predicate for recent samples (last 5 minutes to catch current readings)
        let startDate = Date().addingTimeInterval(-300)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        
        #if DEBUG
        print("[HealthKit] 📅 Query predicate: samples from \(startDate) to now")
        print("[HealthKit] 🔍 Executing heart rate query...")
        #endif
        
        // Create query to get live heart rate updates
        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { _, samples, deletedObjects, anchor, error in
            #if DEBUG
            print("[HealthKit] 📥 Initial query completion handler called")
            #endif
            
            if let error = error {
                #if DEBUG
                print("[HealthKit] ❌ Query error: \(error.localizedDescription)")
                #endif
                return
            }
            
            #if DEBUG
            let sampleCount = samples?.count ?? 0
            let deletedCount = deletedObjects?.count ?? 0
            print("[HealthKit] 📊 Initial query results: \(sampleCount) samples, \(deletedCount) deleted")
            #endif
            
            // Process samples, prioritizing Apple Watch
            self.handleHeartRate(samples: samples, update: update)
        }

        query.updateHandler = { _, samples, deletedObjects, anchor, error in
            #if DEBUG
            print("[HealthKit] 🔄 Query update handler called")
            #endif
            
            if let error = error {
                #if DEBUG
                print("[HealthKit] ❌ Update handler error: \(error.localizedDescription)")
                #endif
                return
            }
            
            #if DEBUG
            let sampleCount = samples?.count ?? 0
            let deletedCount = deletedObjects?.count ?? 0
            print("[HealthKit] 📊 Update results: \(sampleCount) new samples, \(deletedCount) deleted")
            #endif
            
            // Process new samples
            self.handleHeartRate(samples: samples, update: update)
        }

        heartRateQuery = query
        healthStore.execute(query)
        
        #if DEBUG
        print("[HealthKit] ✅ Query executed and stored")
        #endif
        
        // Enable background delivery for continuous updates
        healthStore.enableBackgroundDelivery(for: hrType, frequency: .immediate) { success, error in
            #if DEBUG
            if let error = error {
                print("[HealthKit] ⚠️ Background delivery error: \(error.localizedDescription)")
            } else {
                print("[HealthKit] ✅ Background delivery enabled: \(success)")
            }
            #endif
        }
        
        #if DEBUG
        print("[HealthKit] ✅ Heart rate streaming setup complete")
        #endif
    }

    func stopHeartRateStreaming() {
        #if DEBUG
        print("[HealthKit] 🛑 stopHeartRateStreaming called")
        #endif
        if let query = heartRateQuery {
            healthStore.stop(query)
            #if DEBUG
            print("[HealthKit] ✅ Stopped heart rate query")
            #endif
        } else {
            #if DEBUG
            print("[HealthKit] ⚠️ No active query to stop")
            #endif
        }
        heartRateQuery = nil
    }

    private func handleHeartRate(samples: [HKSample]?, update: (_ bpm: Double) -> Void) {
        #if DEBUG
        print("[HealthKit] 🔄 handleHeartRate called with \(samples?.count ?? 0) samples")
        #endif
        
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
            #if DEBUG
            print("[HealthKit] ⚠️ No valid heart rate samples to process")
            #endif
            return
        }
        
        #if DEBUG
        print("[HealthKit] 📊 Processing \(quantitySamples.count) heart rate samples")
        for (index, sample) in quantitySamples.enumerated() {
            let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let bpm = sample.quantity.doubleValue(for: bpmUnit)
            let sourceName = sample.sourceRevision.source.name
            let timestamp = sample.endDate
            print("[HealthKit]   Sample \(index + 1): \(Int(bpm)) bpm from \(sourceName) at \(timestamp)")
        }
        #endif
        
        // Sort by date (most recent first) and prioritize Apple Watch sources
        let sortedSamples = quantitySamples.sorted { sample1, sample2 in
            // Prioritize Apple Watch sources
            let isWatch1 = sample1.sourceRevision.source.name.contains("Watch") || 
                          sample1.sourceRevision.source.bundleIdentifier.contains("watch")
            let isWatch2 = sample2.sourceRevision.source.name.contains("Watch") || 
                          sample2.sourceRevision.source.bundleIdentifier.contains("watch")
            
            if isWatch1 && !isWatch2 { return true }
            if !isWatch1 && isWatch2 { return false }
            
            // If both or neither are Watch, sort by date (most recent first)
            return sample1.endDate > sample2.endDate
        }
        
        // Use the most recent sample (preferably from Apple Watch)
        if let mostRecent = sortedSamples.first {
            let bpmUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let bpm = mostRecent.quantity.doubleValue(for: bpmUnit)
            
            #if DEBUG
            let sourceName = mostRecent.sourceRevision.source.name
            let bundleId = mostRecent.sourceRevision.source.bundleIdentifier
            let isWatch = sourceName.contains("Watch") || bundleId.contains("watch")
            print("[HealthKit] 💓 Selected heart rate: \(Int(bpm)) bpm from \(sourceName)\(isWatch ? " (Apple Watch ✅)" : "")")
            #endif
            
            update(bpm)
        } else {
            #if DEBUG
            print("[HealthKit] ❌ No sample selected after sorting")
            #endif
        }
    }

    func saveWorkout(session: WorkoutSession) {
        // Check write authorization before attempting to save
        let (_, writeAuth) = checkAuthorizationStatus()
        if !writeAuth {
            #if DEBUG
            print("[HealthKit] ⚠️ Write authorization denied - cannot save workout to Apple Health")
            print("[HealthKit] ⚠️ User needs to enable Workout Type and Active Energy Burned in Settings > Privacy & Security > Health > PushupTrainer")
            #endif
            return
        }
        
        #if DEBUG
        print("[HealthKit] 💾 Saving workout to Apple Health...")
        print("[HealthKit] - Reps: \(session.reps), Duration: \(session.durationSeconds)s, Calories: \(session.caloriesBurned)")
        #endif
        
        let energy = HKQuantity(unit: .kilocalorie(), doubleValue: session.caloriesBurned)
        let metadata: [String: Any] = [
            "mode": session.mode.rawValue,
            "reps": session.reps,
            "avgHR": session.averageHeartRateBPM ?? NSNull(),
            "maxHR": session.maxHeartRateBPM ?? NSNull(),
            "recoveryDrop": session.recoveryHeartRateDropBPM ?? NSNull()
        ]

        // Get heart rate samples for the workout duration
        let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)
        let hrPredicate = HKQuery.predicateForSamples(
            withStart: session.startTime,
            end: session.endTime,
            options: .strictStartDate
        )
        
        // Fetch heart rate samples
        let hrQuery = HKSampleQuery(
            sampleType: hrType!,
            predicate: hrPredicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { [weak self] query, samples, error in
            guard let self = self else { return }
            
            if let error = error {
                #if DEBUG
                print("[HealthKit] ⚠️ Error fetching heart rate samples: \(error.localizedDescription)")
                #endif
                // Continue with workout save even if HR fetch fails
                self.saveWorkoutWithoutHeartRate(session: session, energy: energy, metadata: metadata)
                return
            }
            
            let hrSamples = samples as? [HKQuantitySample] ?? []
            #if DEBUG
            print("[HealthKit] 📊 Found \(hrSamples.count) heart rate samples")
            #endif
            
            self.saveWorkoutWithHeartRate(session: session, energy: energy, metadata: metadata, heartRateSamples: hrSamples)
        }
        
        healthStore.execute(hrQuery)
    }
    
    private func saveWorkoutWithHeartRate(
        session: WorkoutSession,
        energy: HKQuantity,
        metadata: [String: Any],
        heartRateSamples: [HKQuantitySample]
    ) {
        // Double-check write authorization before starting builder
        let (_, writeAuth) = checkAuthorizationStatus()
        guard writeAuth else {
            #if DEBUG
            print("[HealthKit] ⚠️ Write authorization denied - cannot save workout with builder")
            #endif
            return
        }
        
        if #available(iOS 17.0, *) {
            let config = HKWorkoutConfiguration()
            config.activityType = .traditionalStrengthTraining
            
            let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
            
            builder.beginCollection(withStart: session.startTime) { success, error in
                if let error = error {
                    #if DEBUG
                    print("[HealthKit] ❌ Error beginning collection: \(error.localizedDescription)")
                    #endif
                    return
                }
                
                guard success else {
                    #if DEBUG
                    print("[HealthKit] ⚠️ beginCollection returned false")
                    #endif
                    return
                }
                
                // Track completion of add operations
                var operationsToComplete = 0
                var operationsCompleted = 0
                
                // Add energy sample
                if let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                    operationsToComplete += 1
                    let energySample = HKQuantitySample(
                        type: energyType,
                        quantity: energy,
                        start: session.startTime,
                        end: session.endTime
                    )
                    builder.add([energySample]) { success, error in
                        operationsCompleted += 1
                        #if DEBUG
                        if let error = error {
                            print("[HealthKit] ⚠️ Error adding energy sample: \(error.localizedDescription)")
                        } else {
                            print("[HealthKit] ✅ Energy sample added")
                        }
                        #endif
                    }
                }
                
                // Add heart rate samples if available
                if !heartRateSamples.isEmpty {
                    operationsToComplete += 1
                    builder.add(heartRateSamples) { success, error in
                        operationsCompleted += 1
                        #if DEBUG
                        if let error = error {
                            print("[HealthKit] ⚠️ Error adding heart rate samples: \(error.localizedDescription)")
                        } else {
                            print("[HealthKit] ✅ Added \(heartRateSamples.count) heart rate samples")
                        }
                        #endif
                    }
                }
                
                // Wait for all add operations to complete, then end collection
                func checkAndEndCollection() {
                    if operationsCompleted >= operationsToComplete {
                        #if DEBUG
                        print("[HealthKit] ✅ All samples added (\(operationsCompleted)/\(operationsToComplete)), preparing to end collection...")
                        #endif
                        
                        // Add metadata BEFORE ending collection
                        builder.addMetadata(metadata) { success, error in
                            if let error = error {
                                #if DEBUG
                                print("[HealthKit] ⚠️ Error adding metadata: \(error.localizedDescription)")
                                #endif
                            } else {
                                #if DEBUG
                                print("[HealthKit] ✅ Metadata added")
                                #endif
                            }
                            
                            // Now end collection
                            builder.endCollection(withEnd: session.endTime) { success, error in
                                if let error = error {
                                    #if DEBUG
                                    print("[HealthKit] ❌ Error ending collection: \(error.localizedDescription)")
                                    #endif
                                    return
                                }
                                
                                guard success else {
                                    #if DEBUG
                                    print("[HealthKit] ⚠️ endCollection returned false")
                                    #endif
                                    return
                                }
                                
                                #if DEBUG
                                print("[HealthKit] ✅ Collection ended successfully")
                                #endif
                                
                                // Wait a moment for endCollection to fully process, then finish
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    #if DEBUG
                                    print("[HealthKit] 🏁 Finishing workout...")
                                    #endif
                                    builder.finishWorkout { workout, error in
                                        if let error = error {
                                            #if DEBUG
                                            print("[HealthKit] ❌ Error finishing workout: \(error.localizedDescription)")
                                            #endif
                                        } else {
                                            #if DEBUG
                                            print("[HealthKit] ✅ Workout saved successfully to Apple Health")
                                            #endif
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Check again after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            checkAndEndCollection()
                        }
                    }
                }
                
                // Start checking after a brief initial delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    checkAndEndCollection()
                }
            }
        } else {
            let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
            let workout = HKWorkout(
                activityType: .traditionalStrengthTraining,
                start: session.startTime,
                end: session.endTime,
                workoutEvents: nil,
                totalEnergyBurned: energy,
                totalDistance: nil,
                metadata: metadata
            )
            
            healthStore.save(workout) { [weak self] success, error in
                guard let self = self else { return }
                
                if let error = error {
                    #if DEBUG
                    print("[HealthKit] ❌ Error saving workout: \(error.localizedDescription)")
                    #endif
                    return
                }
                
                guard success else { return }
                
                // Add energy sample
                let energySample = HKQuantitySample(
                    type: energyType,
                    quantity: energy,
                    start: session.startTime,
                    end: session.endTime
                )
                self.healthStore.add([energySample], to: workout) { _, _ in }
                
                // Add heart rate samples if available
                if !heartRateSamples.isEmpty {
                    self.healthStore.add(heartRateSamples, to: workout) { success, error in
                        #if DEBUG
                        if let error = error {
                            print("[HealthKit] ⚠️ Error adding heart rate samples: \(error.localizedDescription)")
                        } else {
                            print("[HealthKit] ✅ Added \(heartRateSamples.count) heart rate samples to workout")
                        }
                        #endif
                    }
                }
                
                #if DEBUG
                print("[HealthKit] ✅ Workout saved successfully to Apple Health")
                #endif
            }
        }
    }
    
    private func saveWorkoutWithoutHeartRate(
        session: WorkoutSession,
        energy: HKQuantity,
        metadata: [String: Any]
    ) {
        saveWorkoutWithHeartRate(session: session, energy: energy, metadata: metadata, heartRateSamples: [])
    }
}


