//
//  WorkoutView.swift
//  PushupTrainer
//

import SwiftUI
import AVFoundation
import HealthKit
import Combine

final class WorkoutViewModel: ObservableObject {
    @Published var mode: WorkoutMode = .manual
    @Published var reps: Int = 0
    @Published var isRunning: Bool = true
    @Published var startDate: Date = Date()
    @Published var timestamps: [Date] = []
    @Published var elapsed: Int = 0
    @Published var showPlanPreview: Bool = false
    @Published var selectedTargetReps: Int? = nil
    @Published var selectedPlanDayIndex: Int? = nil

    private var timer: Timer?
    private var autoIncrementTimer: Timer?
    private let haptic = UINotificationFeedbackGenerator()
    private let tts = TTSCoach()
    private let health = HealthKitService.shared
    private let speechRecognizer = SpeechRecognizer()
    private var cancellables = Set<AnyCancellable>()

    @AppStorage("premiumUnlocked") private var premiumUnlocked: Bool = false
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled: Bool = false
    @AppStorage("preferredWorkoutMode") private var preferredWorkoutMode: String = WorkoutMode.manual.rawValue

    // Heart rate live and stats
    @Published var currentHeartRateBPM: Double? = nil
    private var heartRateSamples: [Double] = []
    @Published var isComputingRecovery: Bool = false
    private var recoveryWindowSamples: [Double] = []
    private var recoveryTimer: Timer?
    
    // iOS 17+ Live Workout Manager
    private var liveWorkoutManager: AnyObject? // Will be LiveWorkoutManager on iOS 17+
    private var heartRateCancellable: AnyCancellable?
    private var isUsingLiveWorkout: Bool = false
    
    // Voice mode state
    @Published var showPermissionAlert: Bool = false
    @Published var permissionAlertMessage: String = ""
    @Published var isListeningToVoice: Bool = false
    @Published var speechError: String? = nil
    @Published var isUsingBluetooth: Bool = false
    @Published var currentInputName: String? = nil

    // Expose read-only combined flag for the View layer
    var isHealthSavingEnabled: Bool { premiumUnlocked && healthSyncEnabled }

    init() {
        // Load preferred workout mode from AppStorage
        if let savedMode = WorkoutMode(rawValue: preferredWorkoutMode) {
            mode = savedMode
        } else {
            // Fallback to profile or tap mode
            let profile = ProfileStore.load()
            mode = profile?.defaultMode ?? .manual
        }
        
        // Set up speech recognition callback
        speechRecognizer.onNumberRecognized = { [weak self] number in
            #if DEBUG
            print("[WorkoutViewModel] 🔔 onNumberRecognized callback received: \(number)")
            print("[WorkoutViewModel] - self exists: \(self != nil)")
            print("[WorkoutViewModel] - mode: \(self?.mode.rawValue ?? "nil")")
            print("[WorkoutViewModel] - isRunning: \(self?.isRunning ?? false)")
            #endif
            
            guard let self = self, self.mode == .voice else {
                #if DEBUG
                print("[WorkoutViewModel] ❌ Guard failed - not in voice mode")
                #endif
                return
            }
            
            // In voice mode, only count when workout is running
            // When paused, numbers are detected but not counted (state not updated in recognizer)
            guard self.isRunning else {
                #if DEBUG
                print("[WorkoutViewModel] ⏸️ Workout is paused, ignoring number \(number) - not counting")
                #endif
                return
            }
            
            // Only accept numbers 1-1000 to avoid spurious counts
            if number >= 1 && number <= 1000 {
                #if DEBUG
                print("[WorkoutViewModel] ✅ Received valid number: \(number), incrementing rep")
                #endif
                // For voice mode, increment by 1 when a number is recognized
                // This allows natural counting: "one", "two", "three", etc.
                // or explicit counts: "five", "ten", etc.
                DispatchQueue.main.async {
                    self.incrementRep()
                    #if DEBUG
                    print("[WorkoutViewModel] ✅ Rep incremented, new count: \(self.reps)")
                    #endif
                }
            } else {
                #if DEBUG
                print("[WorkoutViewModel] ❌ Number out of range: \(number)")
                #endif
            }
        }

        // Set up stop command callback - this should trigger the full workout completion flow
        speechRecognizer.onStopCommand = { [weak self] in
            guard let self = self, self.mode == .voice else { return }
            #if DEBUG
            print("[WorkoutViewModel] 🛑 Voice stop command received")
            #endif
            // Post a notification to trigger the finish flow in the view
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("VoiceStopCommandReceived"), object: nil)
            }
        }

        // Listen for speech recognition errors
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpeechRecognizerError"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.object as? String {
                self?.speechError = error
            }
        }
        
        // Sync Bluetooth status from speech recognizer
        speechRecognizer.$isUsingBluetooth
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isBluetooth in
                self?.isUsingBluetooth = isBluetooth
            }
            .store(in: &cancellables)
        
        // Sync input name from speech recognizer
        speechRecognizer.$currentInputName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] inputName in
                self?.currentInputName = inputName
            }
            .store(in: &cancellables)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        // Ensure speech recognizer is fully stopped and cleared
        speechRecognizer.stopListening()
    }
    
    func reloadMode() {
        // Load from AppStorage (preferred mode that was last used)
        if let savedMode = WorkoutMode(rawValue: preferredWorkoutMode) {
            mode = savedMode
        } else {
            // Fallback to profile or tap mode
            let profile = ProfileStore.load()
            mode = profile?.defaultMode ?? .manual
        }
    }

    func start() {
        reps = 0
        elapsed = 0
        timestamps = []
        startDate = Date()
        isRunning = true
        haptic.prepare()
        
        // Persist the workout mode preference when workout starts
        preferredWorkoutMode = mode.rawValue
        
        // For voice mode, request permissions and start listening
        if mode == .voice {
            handleVoiceModeStart()
            return // Voice mode start will call the rest via completion
        }
        
        // For tap mode, timer starts on first rep. For other modes, start immediately
        if mode != .manual {
            startTimer()
        }
        // For timer mode, auto-increment reps every 3 seconds
        if mode == .timer {
            startAutoIncrementTimer()
        }
        tts.speak("Let's crush this workout!")
        #if DEBUG
        print("[Workout] start: target=\(selectedTargetReps ?? -1), mode=\(mode.rawValue)")
        print("[WorkoutViewModel] 💊 Premium: \(premiumUnlocked), Health Sync: \(healthSyncEnabled), Health Available: \(health.isHealthDataAvailable)")
        #endif

        if premiumUnlocked && healthSyncEnabled && health.isHealthDataAvailable {
            #if DEBUG
            print("[WorkoutViewModel] 🚀 Starting HealthKit setup...")
            #endif
            
            // Check current authorization status first
            let (readAuth, writeAuth) = health.checkAuthorizationStatus()
            #if DEBUG
            print("[WorkoutViewModel] 📊 Current authorization - Read: \(readAuth), Write: \(writeAuth)")
            #endif
            
            // If read authorization is already granted, start streaming directly
            if readAuth {
                #if DEBUG
                print("[WorkoutViewModel] ✅ Read authorization already granted, starting heart rate streaming")
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.health.startHeartRateStreaming { bpm in
                        DispatchQueue.main.async {
                            #if DEBUG
                            print("[WorkoutViewModel] 💓 Received heart rate update: \(Int(bpm)) bpm")
                            #endif
                            self.currentHeartRateBPM = bpm
                            self.heartRateSamples.append(bpm)
                        }
                    }
                }
            } else {
                // Request authorization and start streaming
                health.requestAuthorization { [weak self] ok in
                    #if DEBUG
                    print("[WorkoutViewModel] 📞 Authorization callback received: \(ok)")
                    #endif
                    
                    guard let self else { return }
                    
                    // Check actual status after callback
                    let (newReadAuth, _) = self.health.checkAuthorizationStatus()
                    #if DEBUG
                    print("[WorkoutViewModel] 📊 Authorization after callback - Read: \(newReadAuth)")
                    #endif
                    
                    if newReadAuth {
                        #if DEBUG
                        print("[WorkoutViewModel] ✅ HealthKit authorized, starting heart rate streaming")
                        #endif
                        
                        // Small delay to ensure authorization is fully processed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.health.startHeartRateStreaming { bpm in
                                DispatchQueue.main.async {
                                    #if DEBUG
                                    print("[WorkoutViewModel] 💓 Received heart rate update: \(Int(bpm)) bpm")
                                    #endif
                                    self.currentHeartRateBPM = bpm
                                    self.heartRateSamples.append(bpm)
                                }
                            }
                        }
                    } else {
                        #if DEBUG
                        print("[WorkoutViewModel] ❌ HealthKit authorization still denied")
                        #endif
                    }
                }
            }
        } else {
            #if DEBUG
            print("[WorkoutViewModel] ⚠️ HealthKit not enabled:")
            print("[WorkoutViewModel]   - Premium: \(premiumUnlocked)")
            print("[WorkoutViewModel]   - Health Sync: \(healthSyncEnabled)")
            print("[WorkoutViewModel]   - Health Available: \(health.isHealthDataAvailable)")
            #endif
        }
    }
    
    private func handleVoiceModeStart() {
        // Check if already authorized
        if speechRecognizer.isAuthorized {
            startVoiceRecognition()
        } else {
            // Request permissions
            speechRecognizer.requestAuthorization()
            
            // Wait a moment for authorization, then check status
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if self.speechRecognizer.isAuthorized {
                    self.startVoiceRecognition()
                } else {
                    // Show alert about permissions
                    self.showPermissionAlert = true
                    self.permissionAlertMessage = "Microphone and speech recognition permissions are required for voice mode. Please enable them in Settings."
                    // Still allow workout to proceed but without voice recognition
                    self.fallbackToTapMode()
                }
            }
        }
    }
    
    private func startVoiceRecognition() {
        // For voice mode, start timer immediately
        startTimer()
        
        // Start listening immediately - no TTS prompt to avoid audio session conflicts
        speechRecognizer.startListening()
        isListeningToVoice = true
        
        #if DEBUG
        print("[Workout] Voice mode started, listening for rep counts")
        #endif
        
        // Continue with health setup if applicable
        if premiumUnlocked && healthSyncEnabled && health.isHealthDataAvailable {
            #if DEBUG
            print("[WorkoutViewModel] 🚀 Starting HealthKit setup for voice mode...")
            #endif
            
            // Check current authorization status first
            let (readAuth, writeAuth) = health.checkAuthorizationStatus()
            #if DEBUG
            print("[WorkoutViewModel] 📊 Current authorization - Read: \(readAuth), Write: \(writeAuth)")
            #endif
            
            // If read authorization is already granted, start streaming directly
            if readAuth {
                #if DEBUG
                print("[WorkoutViewModel] ✅ Read authorization already granted, starting heart rate streaming")
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.health.startHeartRateStreaming { bpm in
                        DispatchQueue.main.async {
                            #if DEBUG
                            print("[WorkoutViewModel] 💓 Received heart rate update: \(Int(bpm)) bpm")
                            #endif
                            self.currentHeartRateBPM = bpm
                            self.heartRateSamples.append(bpm)
                        }
                    }
                }
            } else {
                // Request authorization and start streaming
                health.requestAuthorization { [weak self] ok in
                    #if DEBUG
                    print("[WorkoutViewModel] 📞 Authorization callback received (voice mode): \(ok)")
                    #endif
                    
                    guard let self else { return }
                    
                    // Check actual status after callback
                    let (newReadAuth, _) = self.health.checkAuthorizationStatus()
                    #if DEBUG
                    print("[WorkoutViewModel] 📊 Authorization after callback - Read: \(newReadAuth)")
                    #endif
                    
                    if newReadAuth {
                        #if DEBUG
                        print("[WorkoutViewModel] ✅ HealthKit authorized, starting heart rate streaming")
                        #endif
                        
                        // Small delay to ensure authorization is fully processed
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.health.startHeartRateStreaming { bpm in
                                DispatchQueue.main.async {
                                    #if DEBUG
                                    print("[WorkoutViewModel] 💓 Received heart rate update: \(Int(bpm)) bpm")
                                    #endif
                                    self.currentHeartRateBPM = bpm
                                    self.heartRateSamples.append(bpm)
                                }
                            }
                        }
                    } else {
                        #if DEBUG
                        print("[WorkoutViewModel] ❌ HealthKit authorization still denied")
                        #endif
                    }
                }
            }
        } else {
            #if DEBUG
            print("[WorkoutViewModel] ⚠️ HealthKit not enabled for voice mode")
            #endif
        }
    }
    
    private func fallbackToTapMode() {
        // If voice mode fails, fall back to tap mode
        isRunning = true
        startTimer()
        tts.speak("Let's crush this workout!")
        #if DEBUG
        print("[Workout] Voice mode failed, falling back to tap mode")
        #endif
    }

    func pause() {
        isRunning = false
        stopTimer()
        stopAutoIncrementTimer()
        // DON'T stop listening in voice mode - keep listening for resume/stop commands
        // Just pause the timer and ignore number state updates (but keep listening for commands)
        if mode == .voice {
            speechRecognizer.setIgnoreNumbers(true)
            #if DEBUG
            print("[WorkoutViewModel] ⏸️ Paused (listening continues, numbers ignored)")
            #endif
        }
    }
    
    func resume() {
        guard !isRunning else { return }
        isRunning = true
        startTimer()
        if mode == .timer {
            startAutoIncrementTimer()
        }
        // Voice mode stays listening throughout, re-enable number state updates
        if mode == .voice {
            speechRecognizer.setIgnoreNumbers(false)
            #if DEBUG
            print("[WorkoutViewModel] ▶️ Resumed (counting re-enabled, listening continued)")
            #endif
        }
    }

    func stop() {
        isRunning = false
        stopTimer()
        stopAutoIncrementTimer()
        // Only stop listening when workout is truly stopped
        if mode == .voice {
            speechRecognizer.stopListening()
            isListeningToVoice = false
            #if DEBUG
            print("[WorkoutViewModel] 🛑 Stopped workout, stopped listening")
            #endif
        }
        health.stopHeartRateStreaming()
    }

    func incrementRep() {
        // Only count reps when workout is running (for all modes)
        guard isRunning else {
            #if DEBUG
            print("[WorkoutViewModel] ⏸️ incrementRep called but workout is paused, not counting")
            #endif
            return
        }
        
        reps += 1
        timestamps.append(Date())
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        
        // In tap mode, start timer on first rep
        if mode == .manual && reps == 1 && timer == nil {
            startTimer()
        }
        
        // Only speak encouragement in non-voice modes to avoid audio session conflicts
        if mode != .voice && reps % 10 == 0 { 
            tts.speak("Nice! \(reps) reps!") 
        }
        
        #if DEBUG
        print("[WorkoutViewModel] Rep incremented to \(reps), isRunning: \(isRunning)")
        #endif
    }

    func completeSession() -> WorkoutSession {
        let end = Date()
        let duration = Int(end.timeIntervalSince(startDate))
        let profile = ProfileStore.load()
        let weight = profile?.weightKg ?? 70
        let calories = Calculations.pushupCalories(reps: reps, durationSeconds: duration, weightKg: weight)
        let avgHR = heartRateSamples.isEmpty ? nil : (heartRateSamples.reduce(0, +) / Double(heartRateSamples.count))
        let maxHR = heartRateSamples.max()
        
        #if DEBUG
        print("[WorkoutViewModel] 📊 Completing session:")
        print("[WorkoutViewModel]   - Reps: \(reps)")
        print("[WorkoutViewModel]   - Duration: \(duration)s")
        print("[WorkoutViewModel]   - Heart rate samples collected: \(heartRateSamples.count)")
        print("[WorkoutViewModel]   - Avg HR: \(avgHR != nil ? "\(Int(avgHR!)) bpm" : "nil")")
        print("[WorkoutViewModel]   - Max HR: \(maxHR != nil ? "\(Int(maxHR!)) bpm" : "nil")")
        print("[WorkoutViewModel]   - Calories: \(calories)")
        #endif
        
        let session = WorkoutSession(
            id: UUID(),
            date: Date(),
            startTime: startDate,
            endTime: end,
            reps: reps,
            durationSeconds: duration,
            mode: mode,
            caloriesBurned: calories,
            notes: "",
            repsTimestamps: timestamps,
            targetRepsAtStart: selectedTargetReps,
            modeDisplayOverride: nil,
            averageHeartRateBPM: avgHR,
            maxHeartRateBPM: maxHR,
            recoveryHeartRateDropBPM: nil
        )
        return session
    }

    func finishWithRecovery(completion: @escaping (WorkoutSession) -> Void) {
        stop() // Stop the timer and workout first
        guard premiumUnlocked && healthSyncEnabled && health.isHealthDataAvailable else {
            #if DEBUG
            print("[WorkoutViewModel] ⚠️ Skipping recovery - HealthKit not enabled")
            #endif
            let session = completeSession()
            markPlanDayComplete()
            completion(session)
            return
        }
        
        // Skip recovery if user explicitly stopped - just complete immediately
        // Recovery is only useful when workout naturally completes
        let session = completeSession()
        markPlanDayComplete()
        completion(session)
        return
        
        // Original recovery logic (commented out for now - can be re-enabled if needed)
        /*
        isComputingRecovery = true
        recoveryWindowSamples = []
        let endSnapshot = Date()
        recoveryTimer?.invalidate()
        recoveryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self else { return }
            if let hr = self.currentHeartRateBPM { self.recoveryWindowSamples.append(hr) }
            if Date().timeIntervalSince(endSnapshot) >= 60 {
                t.invalidate()
                self.isComputingRecovery = false
                self.health.stopHeartRateStreaming()
                let minAfter = self.recoveryWindowSamples.min()
                let drop = (minAfter != nil) ? max(0, baseline - minAfter!) : nil
                var session = self.completeSession()
                session.recoveryHeartRateDropBPM = drop
                self.markPlanDayComplete()
                completion(session)
            }
        }
        RunLoop.main.add(recoveryTimer!, forMode: .common)
        */
    }

    private func markPlanDayComplete() {
        guard var plan = PlanStore.load() else { return }
        
        // Get the target reps for the selected day
        var targetReps: Int?
        if let idx = selectedPlanDayIndex, idx >= 0, idx < plan.days.count {
            targetReps = selectedTargetReps
        }
        
        // Only mark complete if reps >= target
        guard let target = targetReps, reps >= target else { return }
        
        if let idx = selectedPlanDayIndex, idx >= 0, idx < plan.days.count {
            plan.days[idx].isCompleted = true
            plan.days[idx].completedDate = Date()
            PlanStore.save(plan)
            return
        }
        let daysSinceStart = Calendar.current.dateComponents([.day], from: plan.startDate, to: Date()).day ?? 0
        let currentDayIndex = min(daysSinceStart, plan.days.count - 1)
        if currentDayIndex >= 0 && currentDayIndex < plan.days.count {
            plan.days[currentDayIndex].isCompleted = true
            plan.days[currentDayIndex].completedDate = Date()
            PlanStore.save(plan)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.isRunning { self.elapsed += 1 }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }
    
    private func startAutoIncrementTimer() {
        autoIncrementTimer?.invalidate()
        autoIncrementTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.isRunning {
                self.incrementRep()
            }
        }
        RunLoop.main.add(autoIncrementTimer!, forMode: .common)
    }
    
    private func stopAutoIncrementTimer() { autoIncrementTimer?.invalidate(); autoIncrementTimer = nil }
}

struct WorkoutView: View {
    @StateObject private var vm = WorkoutViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var plan: WorkoutPlan? = PlanStore.load()
    @State private var triggerFinish = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack {
                    ZStack {
                        Circle().stroke(.white.opacity(0.2), lineWidth: 8)
                        Text(timeString(vm.elapsed)).font(.headline.monospacedDigit())
                    }.frame(width: 90, height: 90)
                }
                Spacer()
                VStack {
                    Text("Total Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(vm.reps)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }
            }

            if let hr = vm.currentHeartRateBPM {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                    Text("\(Int(hr)) bpm")
                        .font(.headline.monospacedDigit())
                }
                .padding(8)
                .glass(cornerRadius: 12)
                .onAppear {
                    #if DEBUG
                    print("[WorkoutView] 💓 Heart rate UI displayed: \(Int(hr)) bpm")
                    #endif
                }
            }

            ZStack {
                // Progress ring based on selected target reps (fallback to profile target)
                let profile = ProfileStore.load()
                let target = max(1, vm.selectedTargetReps ?? profile?.targetReps ?? 20)
                let progress = min(1.0, Double(vm.reps) / Double(target))
                let hue = 0.0 + (0.33 * progress)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color(hue: hue, saturation: 0.9, brightness: 0.9), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 360, height: 360)
                    .animation(.easeInOut, value: vm.reps)
                    .allowsHitTesting(false)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 320, height: 320)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                    .shadow(radius: 10)
                    .overlay(
                        VStack(spacing: 4) {
                            if vm.reps == 0 {
                                if vm.mode == .voice {
                                    if !vm.isRunning {
                                        Text("Paused")
                                            .font(.title2.bold())
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(vm.isListeningToVoice ? "Listening..." : "Starting...")
                                            .font(.title2.bold())
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text(vm.mode == .manual ? "Tap to Begin" : (!vm.isRunning ? "Paused" : "Starting..."))
                                        .font(.title2.bold())
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("\(vm.reps) / \(target)")
                                    .font(.system(size: 80, weight: .bold, design: .rounded))
                                    .contentTransition(.numericText())
                            }
                            
                            // Show AirPods/Bluetooth connection status
                            if vm.mode == .voice && vm.isUsingBluetooth {
                                HStack(spacing: 4) {
                                    Image(systemName: "airpods")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    if let inputName = vm.currentInputName {
                                        Text(inputName)
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.top, 2)
                            } else if vm.mode == .voice && vm.isListeningToVoice {
                                HStack(spacing: 4) {
                                    Image(systemName: "mic.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("iPhone Mic")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 2)
                            }
                        }
                    )
                    .contentShape(Circle())
                    .onTapGesture {
                        if vm.mode == .manual {
                            vm.incrementRep()
                        }
                    }
            }
            .padding(.top, 60)

            // Mode is selected from Settings as user preference

            HStack { Spacer() }

            Spacer()
        }
        .padding(20)
        .onAppear {
            vm.reloadMode()
            plan = PlanStore.load()
            if plan != nil {
                vm.showPlanPreview = true
            } else {
                vm.start()
            }
        }
        .background(
            ZStack {
                Color(uiColor: .systemBackground)
                LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        )
        .sheet(isPresented: $vm.showPlanPreview) {
            PlanPreviewSheet(plan: plan, onStart: { index, target, mode in
                vm.selectedPlanDayIndex = index
                vm.selectedTargetReps = target
                vm.mode = mode
                vm.showPlanPreview = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    vm.start()
                }
            }, onCancel: {
                vm.showPlanPreview = false
                NotificationCenter.default.post(name: NSNotification.Name("NavigateHome"), object: nil)
                dismiss()
            })
            .interactiveDismissDisabled()
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if vm.isComputingRecovery {
                    Text("Computing recovery (60s)…")
                        .padding(10)
                        .glass(cornerRadius: 12)
                }
                if let error = vm.speechError, vm.mode == .voice {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .glass(cornerRadius: 12)
                }
            }
            .padding(.bottom, 12)
        }
        .alert("Permissions Required", isPresented: $vm.showPermissionAlert) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(vm.permissionAlertMessage)
        }
        .overlay(alignment: .bottomLeading) {
            Button(action: { 
                if vm.isRunning {
                    vm.pause()
                } else {
                    vm.resume()
                }
            }) {
                Image(systemName: vm.isRunning ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .padding(16)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .padding(.leading, 20)
            .padding(.bottom, 80)
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: {
                triggerFinish = true
            }) {
                Image(systemName: vm.isComputingRecovery ? "hourglass" : "stop.fill")
                    .font(.title3)
                    .padding(16)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .padding(.trailing, 20)
            .padding(.bottom, 80)
            .disabled(vm.isComputingRecovery)
        }
        .onChange(of: triggerFinish) { newValue in
            guard newValue else { return }
            guard !vm.isComputingRecovery else { 
                triggerFinish = false
                return 
            }
            
            // Clear any speech errors when stopping
            vm.speechError = nil
            
            #if DEBUG
            print("[WorkoutView] 🛑 Stop button pressed, finishing workout with \(vm.reps) reps")
            #endif
            
            vm.finishWithRecovery { session in
                #if DEBUG
                print("[WorkoutView] 💾 finishWithRecovery completion called with \(session.reps) reps")
                #endif
                
                // Only save session if there are actual reps
                if session.reps > 0 {
                    // Save to Apple Health if enabled
                    if vm.isHealthSavingEnabled {
                        #if DEBUG
                        print("[WorkoutView] 💾 Saving workout to Apple Health...")
                        #endif
                        HealthKitService.shared.saveWorkout(session: session)
                    }
                    
                    // Save to local store
                    var all = SessionStore.load()
                    all.append(session)
                    SessionStore.save(all)
                    
                    // Notify that sessions have been updated
                    NotificationCenter.default.post(name: NSNotification.Name("SessionsUpdated"), object: nil)
                    
                    // Handle notification logic for workout completion
                    NotificationManager.shared.onWorkoutCompleted()
                    
                    #if DEBUG
                    print("[WorkoutView] ✅ Session saved locally")
                    #endif
                }
                
                #if DEBUG
                print("[WorkoutView] 🏠 Navigating to home screen")
                #endif
                // Navigate to home tab (WorkoutView is in a TabView, not presented modally)
                NotificationCenter.default.post(name: NSNotification.Name("NavigateHome"), object: nil)
            }
            triggerFinish = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("VoiceStopCommandReceived"))) { _ in
            // Trigger the same finish flow when voice stop command is received
            triggerFinish = true
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct PlanPreviewSheet: View {
    let plan: WorkoutPlan?
    let onStart: (_ index: Int?, _ targetReps: Int?, _ mode: WorkoutMode) -> Void
    let onCancel: () -> Void
    @State private var selectedTarget: Int? = nil
    @State private var selectedIndex: Int? = nil
    @State private var selectedMode: WorkoutMode = .manual
    
    private var modeDescriptionView: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(selectedMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var modeSectionView: some View {
        Section("Workout Mode") {
            Picker("Mode", selection: $selectedMode) {
                Text("Tap").tag(WorkoutMode.manual)
                Text("Timer").tag(WorkoutMode.timer)
                Text("Voice").tag(WorkoutMode.voice)
            }
            .pickerStyle(.segmented)
            
            modeDescriptionView
        }
    }
    
    private func planOverviewSection(plan: WorkoutPlan) -> some View {
        Section("Plan Overview") {
            HStack {
                Text("Total Days")
                Spacer()
                Text("\(plan.totalDays)")
            }
            HStack {
                Text("Progress")
                Spacer()
                Text("\(plan.days.filter { $0.isCompleted }.count) / \(plan.totalDays)")
            }
        }
    }
    
    private func selectDaySection(plan: WorkoutPlan) -> some View {
        Section("Select Day") {
            ForEach(Array(plan.days.enumerated()), id: \.element.id) { pair in
                let day = pair.element
                let idx = pair.offset
                Button(action: { selectedIndex = idx; selectedTarget = day.targetReps }) {
                    HStack {
                        Image(systemName: (selectedIndex == idx) ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle((selectedIndex == idx) ? .blue : .secondary)
                        Text("Day \(day.dayNumber)")
                        Spacer()
                        HStack(spacing: 8) {
                            if day.isCompleted { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            Text("\(day.targetReps) reps")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                if let plan = plan {
                    modeSectionView
                    planOverviewSection(plan: plan)
                    selectDaySection(plan: plan)
                } else {
                    Text("No plan available.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Start Workout") { onStart(selectedIndex, selectedTarget, selectedMode) } }
            }
            .onAppear {
                // Load preferred mode from AppStorage (last used mode)
                let preferredModeRaw = UserDefaults.standard.string(forKey: "preferredWorkoutMode") ?? WorkoutMode.manual.rawValue
                if let savedMode = WorkoutMode(rawValue: preferredModeRaw) {
                    selectedMode = savedMode
                } else if let profile = ProfileStore.load() {
                    selectedMode = profile.defaultMode ?? .manual
                } else {
                    selectedMode = .manual
                }
                
                // Auto-select the first incomplete day after the last completed day
                if let plan = plan {
                    var lastCompletedIndex = -1
                    for (index, day) in plan.days.enumerated() {
                        if day.isCompleted {
                            lastCompletedIndex = index
                        }
                    }
                    let nextIndex = lastCompletedIndex + 1
                    if nextIndex < plan.days.count {
                        selectedIndex = nextIndex
                        selectedTarget = plan.days[nextIndex].targetReps
                    }
                }
            }
        }
    }
}


