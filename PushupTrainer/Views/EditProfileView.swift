//
//  EditProfileView.swift
//  PushupTrainer
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile? = ProfileStore.load()
    @State private var avatarSelection: PhotosPickerItem? = nil
    @State private var heightText: String = ""
    @State private var weightText: String = ""
    @State private var heightUnit: Units.HeightUnit = .cm
    @State private var weightUnit: Units.WeightUnit = .kg

    var body: some View {
        Form {
            if var p = profile {
                Section("Profile") {
                    HStack {
                        if let data = p.avatarImageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill().frame(width: 64, height: 64).clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill").font(.system(size: 64))
                        }
                        VStack(alignment: .leading) {
                            TextField("Name", text: Binding(
                                get: { p.displayName ?? "" },
                                set: { newVal in p.displayName = newVal; profile = p; ProfileStore.save(p) }
                            ))
                            Text("Edit your display name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    PhotosPicker(selection: $avatarSelection, matching: .images) {
                        Label("Change Avatar", systemImage: "photo")
                    }
                    .onChange(of: avatarSelection) { oldValue, newValue in
                        guard let newValue else { return }
                        Task {
                            if let data = try? await newValue.loadTransferable(type: Data.self) {
                                p.avatarImageData = data
                                profile = p
                                ProfileStore.save(p)
                            }
                        }
                    }
                }

                Section("Personal Information") {
                    Picker("Gender", selection: Binding(
                        get: { p.gender },
                        set: { newVal in p.gender = newVal; profile = p; ProfileStore.save(p) }
                    )) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                        Text("Other").tag("Other")
                    }
                    
                    Stepper("Age: \(p.age)", value: Binding(
                        get: { p.age },
                        set: { newVal in p.age = newVal; profile = p; ProfileStore.save(p) }
                    ), in: 1...120)
                }

                Section("Measurements") {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        
                        Picker("", selection: $heightUnit) {
                            Text("cm").tag(Units.HeightUnit.cm)
                            Text("ft").tag(Units.HeightUnit.ft)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: heightText) { _, _ in updateHeightFromText(&p) }
                        .onChange(of: heightUnit) { _, _ in 
                            updateHeightDisplay(p)
                            updateHeightFromText(&p)
                        }
                    }
                    
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        
                        Picker("", selection: $weightUnit) {
                            Text("kg").tag(Units.WeightUnit.kg)
                            Text("lb").tag(Units.WeightUnit.lb)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: weightText) { _, _ in updateWeightFromText(&p) }
                        .onChange(of: weightUnit) { _, _ in 
                            updateWeightDisplay(p)
                            updateWeightFromText(&p)
                        }
                    }
                }

                Section("Workout Preferences") {
                    Picker("Default Mode", selection: Binding(
                        get: { p.defaultMode ?? .manual },
                        set: { newVal in p.defaultMode = newVal; profile = p; ProfileStore.save(p) }
                    )) {
                        Text("Manual").tag(WorkoutMode.manual)
                        Text("Timer").tag(WorkoutMode.timer)
                        Text("Voice").tag(WorkoutMode.voice)
                    }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .defaultScrollAnchor(.top)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            if let p = profile {
                heightUnit = p.units.height
                weightUnit = p.units.weight
                updateHeightDisplay(p)
                updateWeightDisplay(p)
            }
        }
    }
    
    private func updateHeightDisplay(_ p: UserProfile) {
        switch p.units.height {
        case .cm:
            heightText = String(format: "%.1f", p.heightCm)
        case .ft:
            heightText = String(format: "%.2f", p.heightCm / 30.48)
        }
    }
    
    private func updateWeightDisplay(_ p: UserProfile) {
        switch p.units.weight {
        case .kg:
            weightText = String(format: "%.1f", p.weightKg)
        case .lb:
            weightText = String(format: "%.1f", p.weightKg / 0.45359237)
        }
    }
    
    private func updateHeightFromText(_ p: inout UserProfile) {
        guard let value = Double(heightText) else { return }
        switch heightUnit {
        case .cm:
            p.heightCm = value
        case .ft:
            p.heightCm = value * 30.48
        }
        p.units.height = heightUnit
        profile = p
        ProfileStore.save(p)
    }
    
    private func updateWeightFromText(_ p: inout UserProfile) {
        guard let value = Double(weightText) else { return }
        switch weightUnit {
        case .kg:
            p.weightKg = value
        case .lb:
            p.weightKg = value * 0.45359237
        }
        p.units.weight = weightUnit
        profile = p
        ProfileStore.save(p)
    }
}

