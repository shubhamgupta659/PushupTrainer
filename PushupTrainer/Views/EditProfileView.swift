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
                    .onChange(of: avatarSelection) { item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                p.avatarImageData = data
                                profile = p
                                ProfileStore.save(p)
                            }
                        }
                    }
                }

                Section("Goals") {
                    Stepper("Target Reps: \(p.targetReps)", value: Binding(
                        get: { p.targetReps },
                        set: { newVal in p.targetReps = newVal; profile = p; ProfileStore.save(p) }
                    ), in: 1...500)

                    Stepper("Current Max: \(p.currentMaxPushups)", value: Binding(
                        get: { p.currentMaxPushups },
                        set: { newVal in p.currentMaxPushups = newVal; profile = p; ProfileStore.save(p) }
                    ), in: 1...1000)
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
    }
}

