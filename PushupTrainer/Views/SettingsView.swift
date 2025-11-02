//
//  SettingsView.swift
//  PushupTrainer
//

import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var profile: UserProfile? = ProfileStore.load()
    @AppStorage("premiumUnlocked") private var premiumUnlocked: Bool = false
    @AppStorage("analyticsOptIn") private var analyticsOptIn: Bool = false
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled: Bool = false
    @State private var avatarSelection: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    NavigationLink(destination: EditProfileView()) {
                        HStack {
                            if let p = profile, let data = p.avatarImageData, let ui = UIImage(data: data) {
                                Image(uiImage: ui).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle").font(.largeTitle)
                            }
                            VStack(alignment: .leading) {
                                Text(profile?.displayName ?? "Edit Profile")
                                    .font(.headline)
                                Text("Tap to edit profile and goals")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                Section("Theme") {
                    Picker("Appearance", selection: $themeManager.theme) {
                        ForEach(AppTheme.allCases) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                }
                
                Section("Accent Color") {
                    HStack(spacing: 12) {
                        ForEach(AccentColor.allCases) { accent in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    themeManager.accentColor = accent
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(accent.color)
                                        .frame(width: 36, height: 36)
                                    
                                    if themeManager.accentColor == accent {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }

            // Removed View Plan; reset moved into Edit Plan screen

            Section("Premium") {
                Toggle("Premium Unlocked (placeholder)", isOn: $premiumUnlocked)
                Text("Voice Mode, AI Coach enhancements, Health/Cloud sync")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Health") {
                Toggle("Apple Health Sync", isOn: Binding(
                    get: { premiumUnlocked && healthSyncEnabled },
                    set: { newVal in healthSyncEnabled = premiumUnlocked ? newVal : false }
                ))
                .disabled(!premiumUnlocked)
                Text(premiumUnlocked ? "Sync heart rate during workouts." : "Premium required to enable Health sync.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Toggle("Analytics (local) Opt-In", isOn: $analyticsOptIn)
                Text("Data stays on-device unless you enable sync.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                Button(role: .destructive, action: resetAllData) {
                    Label("Reset All Data", systemImage: "trash")
                }
            }
            }
            .navigationTitle("Settings")
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
            .onAppear { profile = ProfileStore.load() }
        }
    }

    private func resetAllData() {
        SessionStore.save([])
        PlanStore.delete()
        UserDefaults.standard.removeObject(forKey: "userProfile")
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        profile = nil
    }
}


