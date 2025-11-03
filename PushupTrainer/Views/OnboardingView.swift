//
//  OnboardingView.swift
//  PushupTrainer
//

import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @State private var displayName: String = ""
    @State private var gender: String = "Male"
    @State private var ageValue: Int = 25
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var targetReps: String = "100"
    @State private var currentMax: String = "10"
    @State private var targetDays: String = "45"
    @State private var planStyle: PlanStyle = .linear
    @State private var workoutMode: WorkoutMode = .manual
    @State private var heightUnit: Units.HeightUnit = .cm
    @State private var weightUnit: Units.WeightUnit = .kg
    @State private var avatarSelection: PhotosPickerItem? = nil
    @State private var avatarData: Data? = nil
    @State private var showPolicy: Bool = false
    @State private var agreePolicy: Bool = false

    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header safely inset from the Dynamic Island / notch
                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to Push-Up Trainer")
                        .font(.title.bold())      
                        .lineLimit(1)          
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true) 
                    Text("Set Up Your Fitness Profile")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 60)

                // Avatar at the top
                PhotosPicker(selection: $avatarSelection, matching: .images) {
                    HStack {
                        if let data = avatarData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill().frame(width: 52, height: 52).clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.badge.plus").font(.title2)
                        }
                        Text("Add Avatar")
                        Spacer()
                    }
                    .padding().glass(cornerRadius: 14)
                }
                .onChange(of: avatarSelection, { oldValue, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self) { avatarData = data }
                    }
                })

                VStack(spacing: 12) {
                    HStack { Text("Name"); Spacer(); TextField("", text: $displayName).multilineTextAlignment(.trailing) }
                        .padding().glass()
                    HStack {
                        Text("Gender")
                        Spacer()
                        Picker("", selection: $gender) {
                            Text("Male").tag("Male")
                            Text("Female").tag("Female")
                            Text("Other").tag("Other")
                            Text("Prefer not to say").tag("Prefer not to say")
                        }.pickerStyle(.menu)
                    }
                        .padding().glass()
                    HStack {
                        Text("Age")
                        Spacer()
                        Picker("", selection: $ageValue) {
                            ForEach(13...80, id: \.self) { age in Text("\(age)").tag(age) }
                        }.pickerStyle(.menu)
                    }
                        .padding().glass()

                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("", text: $height).keyboardType(.decimalPad).frame(width: 80).multilineTextAlignment(.trailing)
                        Picker("", selection: $heightUnit) {
                            Text("cm").tag(Units.HeightUnit.cm)
                            Text("ft").tag(Units.HeightUnit.ft)
                        }.pickerStyle(.segmented).frame(width: 120)
                    }.padding().glass()

                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("", text: $weight).keyboardType(.decimalPad).frame(width: 80).multilineTextAlignment(.trailing)
                        Picker("", selection: $weightUnit) {
                            Text("kg").tag(Units.WeightUnit.kg)
                            Text("lb").tag(Units.WeightUnit.lb)
                        }.pickerStyle(.segmented).frame(width: 120)
                    }.padding().glass()

                    HStack { Text("Target Reps"); Spacer(); TextField("", text: $targetReps).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                        .padding().glass()

                    HStack { Text("Current Max"); Spacer(); TextField("", text: $currentMax).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                        .padding().glass()

                    HStack { Text("Target Days"); Spacer(); TextField("", text: $targetDays).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                        .padding().glass()
                    
                    HStack {
                        Text("Plan Style")
                        Spacer()
                        Picker("", selection: $planStyle) {
                            ForEach(PlanStyle.allCases) { style in
                                Text(style.label).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding().glass()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preferred Workout Mode")
                            .font(.headline)
                        
                        Text("Choose how you'd like to track your push-ups during workouts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 8) {
                            ForEach(WorkoutMode.allCases, id: \.rawValue) { mode in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        workoutMode = mode
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: mode == .manual ? "hand.tap.fill" : mode == .timer ? "timer" : "mic.fill")
                                            .font(.title3)
                                            .frame(width: 28)
                                            .foregroundStyle(workoutMode == mode ? themeManager.accentColor.color : .secondary)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(mode.displayName)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(workoutMode == mode ? themeManager.accentColor.color : .primary)
                                            
                                            Text(mode.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.leading)
                                        }
                                        
                                        Spacer()
                                        
                                        if workoutMode == mode {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(themeManager.accentColor.color)
                                                .font(.title3)
                                        } else {
                                            Circle()
                                                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 2)
                                                .frame(width: 24, height: 24)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(workoutMode == mode ? themeManager.accentColor.color.opacity(0.1) : Color(uiColor: .secondarySystemGroupedBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(workoutMode == mode ? themeManager.accentColor.color.opacity(0.5) : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding().glass()
                }

                // Policy / Agreement
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { showPolicy = true }) {
                        Text("Privacy Policy & Terms")
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Toggle(isOn: $agreePolicy) { Text("I agree to the Privacy Policy and User Agreement").lineLimit(1).minimumScaleFactor(0.8) }
                }
                .padding(.top, 8)

                Button(action: save) {
                    Text("Continue")
                        .font(.headline).padding().frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 4)
                .disabled(!isFormValid())

                // Add bottom padding for better scrolling experience
                Color.clear.frame(height: 40)
            }
            .padding(20)
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
        .sheet(isPresented: $showPolicy) { PolicyView() }
    }

    private func normalizedHeightCm() -> Double {
        let h = Double(height) ?? 0
        switch heightUnit {
        case .cm: return h
        case .ft: return h * 30.48
        }
    }

    private func normalizedWeightKg() -> Double {
        let w = Double(weight) ?? 0
        switch weightUnit {
        case .kg: return w
        case .lb: return w * 0.45359237
        }
    }

    private func isFormValid() -> Bool {
        let nameOk = !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        let heightOk = Double(height) ?? 0 > 0
        let weightOk = Double(weight) ?? 0 > 0
        let targetOk = Int(targetReps) ?? 0 > 0
        let currentOk = Int(currentMax) ?? 0 > 0
        let daysOk = Int(targetDays) ?? 0 > 0
        return agreePolicy && nameOk && heightOk && weightOk && targetOk && currentOk && daysOk
    }

    private func save() {
        let now = Date()
        let profile = UserProfile(
            id: UUID(),
            displayName: displayName.isEmpty ? nil : displayName,
            gender: gender,
            age: ageValue,
            heightCm: normalizedHeightCm(),
            weightKg: normalizedWeightKg(),
            targetReps: Int(targetReps) ?? 0,
            currentMaxPushups: Int(currentMax) ?? 0,
            units: Units(height: heightUnit, weight: weightUnit),
            avatarImageData: avatarData,
            defaultMode: workoutMode,
            createdAt: now,
            updatedAt: now,
            onboardingDate: now
        )
        ProfileStore.save(profile)
        
        // Save preferred workout mode to AppStorage
        UserDefaults.standard.set(workoutMode.rawValue, forKey: "preferredWorkoutMode")
        
        // Generate initial workout plan based on selected style
        guard let tgt = Int(targetReps), let cur = Int(currentMax), let days = Int(targetDays) else { return }
        var daysArray: [PlanDay] = []
        let delta = max(0, tgt - cur)
        
        switch planStyle {
        case .linear:
            for i in 1...max(1, days) {
                let fraction = Double(i) / Double(max(1, days))
                let reps = cur + Int(round(Double(delta) * fraction))
                daysArray.append(PlanDay(id: UUID(), dayNumber: i, targetReps: min(max(cur, reps), tgt), isCompleted: false, completedDate: nil))
            }
        case .exponential:
            for i in 1...max(1, days) {
                let t = Double(i) / Double(max(1, days))
                let eased = pow(t, 1.5) // Slightly slower ramp than t^2
                let reps = cur + Int(round(Double(delta) * eased))
                daysArray.append(PlanDay(id: UUID(), dayNumber: i, targetReps: min(max(cur, reps), tgt), isCompleted: false, completedDate: nil))
            }
        case .stepwise:
            let steps = max(1, min(days / 5, 10))
            let repsPerStep = Double(delta) / Double(steps)
            for i in 1...max(1, days) {
                let stepIndex = Int(floor(Double(i) * Double(steps) / Double(max(1, days))))
                let reps = cur + Int(round(repsPerStep * Double(stepIndex)))
                daysArray.append(PlanDay(id: UUID(), dayNumber: i, targetReps: min(max(cur, reps), tgt), isCompleted: false, completedDate: nil))
            }
        }
        
        // Ensure the last day exactly matches the target reps
        if let last = daysArray.indices.last { daysArray[last].targetReps = tgt }
        
        let plan = WorkoutPlan(id: UUID(), startDate: Date(), totalDays: days, days: daysArray, targetReps: tgt, currentMax: cur)
        PlanStore.save(plan)
        
        // Save plan style preference
        UserDefaults.standard.set(planStyle.rawValue, forKey: "planStyle")
        
        onFinish()
    }
}

// Simple policy screen
struct PolicyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy & Terms")
                        .font(.title.bold())
                    Text(policyText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationTitle("Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private let policyText: String = """
Push‑Up Trainer respects your privacy. We store profile and workout data on‑device by default. If you enable integrations (like Apple Health), data may be shared with that service solely to provide the feature. We never sell personal data.

What we collect
- Profile you provide (name, age, height, weight, goals)
- Workout sessions (reps, duration, optional heart rate if enabled)

How we use it
- Generate and adapt your training plan
- Show progress and stats
- Improve the in‑app coaching experience

Your choices
- You control optional integrations in Settings
- You can edit or delete your data at any time in Settings → Data

Terms
- This app provides fitness guidance but does not replace professional medical advice. Consult a physician before starting any fitness program. Use at your own risk.

Contact
- For questions or requests, contact the developer from the store listing.
"""


