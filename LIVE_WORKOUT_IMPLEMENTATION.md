# HKLiveWorkoutBuilder Implementation Guide

## Overview
This document explains how to integrate `HKLiveWorkoutBuilder` (iOS 17+) alongside the existing iOS 16 implementation.

## What's Been Implemented

### 1. LiveWorkoutManager.swift ✅
Created a new class that handles iOS 17+ live workouts:
- **Automatic heart rate tracking** via delegate callbacks
- **Session state management** (running, paused, ended)
- **Automatic energy tracking**
- **Clean async/await API**

Location: `/PushupTrainer/Services/LiveWorkoutManager.swift`

### 2. HealthKitService Updates ✅
Added `isLiveWorkoutBuilderAvailable` property to check iOS 17+ availability.

## How to Integrate into WorkoutViewModel

### Step 1: Add Live Workout Support to `start()`

Replace the HealthKit setup section (~lines 201-266) with:

```swift
if premiumUnlocked && healthSyncEnabled && health.isHealthDataAvailable {
    // Try iOS 17+ Live Workout Builder first
    if #available(iOS 17.0, *), health.isLiveWorkoutBuilderAvailable {
        #if DEBUG
        print("[WorkoutViewModel] 🚀 Using iOS 17+ HKLiveWorkoutBuilder...")
        #endif
        startLiveWorkout()
    } else {
        // Fallback to iOS 16 manual heart rate streaming
        #if DEBUG
        print("[WorkoutViewModel] 🔄 Using iOS 16 manual heart rate streaming...")
        #endif
        startManualHeartRateTracking()
    }
}
```

### Step 2: Add Live Workout Methods

```swift
@available(iOS 17.0, *)
private func startLiveWorkout() {
    let manager = LiveWorkoutManager()
    self.liveWorkoutManager = manager
    self.isUsingLiveWorkout = true
    
    // Subscribe to heart rate updates
    heartRateCancellable = manager.$currentHeartRate.sink { [weak self] heartRate in
        guard let self = self, let bpm = heartRate else { return }
        self.currentHeartRateBPM = bpm
        self.heartRateSamples.append(bpm)
    }
    
    Task {
        do {
            try await manager.startWorkout()
            #if DEBUG
            print("[WorkoutViewModel] ✅ Live workout started successfully")
            #endif
        } catch {
            #if DEBUG
            print("[WorkoutViewModel] ❌ Failed to start live workout: \(error)")
            #endif
            // Fallback to manual tracking
            isUsingLiveWorkout = false
            startManualHeartRateTracking()
        }
    }
}

private func startManualHeartRateTracking() {
    // Existing iOS 16 heart rate code (lines 206-266)
    let (readAuth, writeAuth) = health.checkAuthorizationStatus()
    
    if readAuth {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.health.startHeartRateStreaming { bpm in
                DispatchQueue.main.async {
                    self.currentHeartRateBPM = bpm
                    self.heartRateSamples.append(bpm)
                }
            }
        }
    } else {
        // Request auth and start streaming...
        // (keep existing code)
    }
}
```

### Step 3: Update `stop()` Method

```swift
func stop() {
    isRunning = false
    timer?.invalidate()
    autoIncrementTimer?.invalidate()
    speechRecognizer.stopListening()
    
    // Stop heart rate based on iOS version
    if isUsingLiveWorkout {
        if #available(iOS 17.0, *), let manager = liveWorkoutManager as? LiveWorkoutManager {
            Task {
                do {
                    let workout = try await manager.endWorkout()
                    #if DEBUG
                    print("[WorkoutViewModel] ✅ Live workout ended and saved")
                    #endif
                } catch {
                    #if DEBUG
                    print("[WorkoutViewModel] ❌ Error ending live workout: \(error)")
                    #endif
                }
            }
        }
        heartRateCancellable?.cancel()
        liveWorkoutManager = nil
        isUsingLiveWorkout = false
    } else {
        health.stopHeartRateStreaming()
    }
}
```

### Step 4: Update `finishWithRecovery()`

```swift
func finishWithRecovery(completion: @escaping (WorkoutSession) -> Void) {
    stop()
    
    // If using iOS 17+ live workout, it's already saved automatically
    if isUsingLiveWorkout {
        #if DEBUG
        print("[WorkoutViewModel] ℹ️ Using live workout - already saved to HealthKit")
        #endif
        let session = completeSession()
        markPlanDayComplete()
        completion(session)
        return
    }
    
    // For iOS 16, manually save workout
    let session = completeSession()
    markPlanDayComplete()
    
    if premiumUnlocked && healthSyncEnabled {
        HealthKitService.shared.saveWorkout(session: session)
    }
    
    completion(session)
}
```

## Key Benefits

### iOS 17+ Users Get:
✅ **Automatic heart rate** - No manual queries, just works  
✅ **Better Apple Watch sync** - Seamless connection  
✅ **Automatic saving** - Workout saved when ended  
✅ **Session state tracking** - Proper pause/resume support  
✅ **Less battery drain** - More efficient data collection  

### iOS 16 Users Keep:
✅ **Full functionality** - Nothing changes  
✅ **Manual control** - Existing heart rate streaming  
✅ **Tested code** - No regressions  

## Testing Checklist

- [ ] Test on iOS 17+ device - should use `LiveWorkoutManager`
- [ ] Test on iOS 16 device - should use legacy streaming
- [ ] Test heart rate display during workout
- [ ] Test workout save to Apple Health
- [ ] Test pause/resume functionality
- [ ] Test app backgrounding during workout

## Migration Path

1. **Phase 1**: Add live workout as optional (current)
2. **Phase 2**: Test with beta users (iOS 17+)
3. **Phase 3**: Drop iOS 16 support (future)
4. **Phase 4**: Remove legacy code, use only LiveWorkoutManager

## Notes

- `LiveWorkoutManager` requires iOS 17.0+
- Uses `@available` checks for safety
- Graceful fallback to iOS 16 code
- No breaking changes to existing functionality
- Can be rolled back easily if issues arise

## Debug Logs to Watch For

```
[WorkoutViewModel] 🚀 Using iOS 17+ HKLiveWorkoutBuilder...
[LiveWorkout] ✅ Live workout started - waiting for heart rate data...
[LiveWorkout] 💓 Heart rate updated: 120 bpm
[LiveWorkout] ✅ Workout saved to HealthKit
```

If you see these, iOS 17+ integration is working!

