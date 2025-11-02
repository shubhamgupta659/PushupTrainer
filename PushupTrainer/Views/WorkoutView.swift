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

    @AppStorage("premiumUnlocked") private var premiumUnlocked: Bool = false
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled: Bool = false

    // Heart rate live and stats
    @Published var currentHeartRateBPM: Double? = nil
    private var heartRateSamples: [Double] = []
    @Published var isComputingRecovery: Bool = false
    private var recoveryWindowSamples: [Double] = []
    private var recoveryTimer: Timer?

    // Expose read-only combined flag for the View layer
    var isHealthSavingEnabled: Bool { premiumUnlocked && healthSyncEnabled }

    init() {
        let profile = ProfileStore.load()
        mode = profile?.defaultMode ?? .manual
    }
    
    func reloadMode() {
        let profile = ProfileStore.load()
        mode = profile?.defaultMode ?? .manual
    }

    func start() {
        reps = 0
        elapsed = 0
        timestamps = []
        startDate = Date()
        isRunning = true
        haptic.prepare()
        // For manual mode, timer starts on first rep. For other modes, start immediately
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
        #endif

        if premiumUnlocked && healthSyncEnabled && health.isHealthDataAvailable {
            health.requestAuthorization { [weak self] ok in
                guard let self, ok else { return }
                self.health.startHeartRateStreaming { bpm in
                    DispatchQueue.main.async {
                        self.currentHeartRateBPM = bpm
                        self.heartRateSamples.append(bpm)
                    }
                }
            }
        }
    }

    func pause() {
        isRunning = false
        stopTimer()
        stopAutoIncrementTimer()
    }

    func stop() {
        isRunning = false
        stopTimer()
        stopAutoIncrementTimer()
        health.stopHeartRateStreaming()
    }

    func incrementRep() {
        guard isRunning else { return }
        reps += 1
        timestamps.append(Date())
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        
        // In manual mode, start timer on first rep
        if mode == .manual && reps == 1 && timer == nil {
            startTimer()
        }
        
        if reps % 10 == 0 { tts.speak("Nice! \(reps) reps!") }
    }

    func completeSession() -> WorkoutSession {
        let end = Date()
        let duration = Int(end.timeIntervalSince(startDate))
        let profile = ProfileStore.load()
        let weight = profile?.weightKg ?? 70
        let calories = Calculations.calories(met: .moderate, weightKg: weight, durationSeconds: duration)
        let avgHR = heartRateSamples.isEmpty ? nil : (heartRateSamples.reduce(0, +) / Double(heartRateSamples.count))
        let maxHR = heartRateSamples.max()
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
            averageHeartRateBPM: avgHR,
            maxHeartRateBPM: maxHR,
            recoveryHeartRateDropBPM: nil
        )
        return session
    }

    func finishWithRecovery(completion: @escaping (WorkoutSession) -> Void) {
        stop() // Stop the timer and workout first
        guard premiumUnlocked && healthSyncEnabled && health.isHealthDataAvailable, let baseline = currentHeartRateBPM else {
            let session = completeSession()
            markPlanDayComplete()
            completion(session)
            return
        }
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
                                Text(vm.mode == .manual ? "Tap to Begin" : "Starting...")
                                    .font(.title2.bold())
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(vm.reps) / \(target)")
                                    .font(.system(size: 80, weight: .bold, design: .rounded))
                                    .contentTransition(.numericText())
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
            LinearGradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
            if vm.isComputingRecovery {
                Text("Computing recovery (60s)…")
                    .padding(10)
                    .glass(cornerRadius: 12)
                    .padding(.bottom, 12)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Button(action: { vm.isRunning ? vm.pause() : vm.start() }) {
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
                guard !vm.isComputingRecovery else { return }
                vm.finishWithRecovery { session in
                    // Only save session if there are actual reps
                    if session.reps > 0 {
                        if vm.isHealthSavingEnabled { HealthKitService.shared.saveWorkout(session: session) }
                        var all = SessionStore.load()
                        all.append(session)
                        SessionStore.save(all)
                        // Notify that sessions have been updated
                        NotificationCenter.default.post(name: NSNotification.Name("SessionsUpdated"), object: nil)
                    }
                    dismiss()
                }
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
                Text("Manual").tag(WorkoutMode.manual)
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
                // Load default mode from profile
                if let profile = ProfileStore.load() {
                    selectedMode = profile.defaultMode ?? .manual
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


