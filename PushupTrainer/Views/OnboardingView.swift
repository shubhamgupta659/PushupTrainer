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
    @State private var heightUnit: Units.HeightUnit = .cm
    @State private var weightUnit: Units.WeightUnit = .kg
    @State private var avatarSelection: PhotosPickerItem? = nil
    @State private var avatarData: Data? = nil
    @State private var showPolicy: Bool = false
    @State private var agreePolicy: Bool = false

    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header safely inset from the Dynamic Island / notch
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Push-Up Trainer")
                    .font(.largeTitle.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text("Set Up Your Fitness Profile")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 30)

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

            Spacer()
        }
        .padding(20)
        .background(
            Group {
                if shouldUseLightTheme {
                    LinearGradient(gradient: Gradient(colors: [Color.white, Color(white:0.95)]), startPoint: .top, endPoint: .bottom)
                } else {
                    LinearGradient(gradient: Gradient(colors: [Color(red:0.05, green:0.08, blue:0.18), Color(red:0.18, green:0.06, blue:0.20)]), startPoint: .top, endPoint: .bottom)
                }
            }
            .ignoresSafeArea()
            .id(themeManager.theme)
        )
        .sheet(isPresented: $showPolicy) { PolicyView() }
    }

    private var shouldUseLightTheme: Bool {
        switch themeManager.theme {
        case .light:
            return true
        case .dark:
            return false
        case .system:
            return (UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }.first?.traitCollection.userInterfaceStyle == .light)
        }
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
            defaultMode: .manual,
            createdAt: Date(),
            updatedAt: Date()
        )
        ProfileStore.save(profile)
        
        // Generate initial workout plan
        let heightM = normalizedHeightCm() / 100.0
        let weight = normalizedWeightKg()
        let bmi = weight > 0 && heightM > 0 ? weight / (heightM * heightM) : 22.0
        var plan = PlanGenerator.generate(
            targetReps: Int(targetReps) ?? 20,
            currentMax: Int(currentMax) ?? 10,
            age: ageValue,
            bmi: bmi
        )
        // Override total days based on user input
        if let days = Int(targetDays), days != plan.totalDays {
            if days < plan.days.count { plan.days = Array(plan.days.prefix(days)) }
            if days > plan.days.count {
                let lastNum = plan.days.last?.dayNumber ?? 0
                let tgt = Int(targetReps) ?? plan.targetReps
                for i in 1...max(0, days - plan.days.count) {
                    plan.days.append(PlanDay(id: UUID(), dayNumber: lastNum + i, targetReps: tgt, isCompleted: false, completedDate: nil))
                }
            }
            plan.totalDays = days
        }
        PlanStore.save(plan)
        
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


