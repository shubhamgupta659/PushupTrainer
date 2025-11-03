//
//  SettingsView.swift
//  PushupTrainer
//

import SwiftUI
import PhotosUI
#if canImport(WidgetKit)
import WidgetKit
#endif

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var iCloudSync = iCloudSyncService.shared
    @State private var profile: UserProfile? = ProfileStore.load()
    @AppStorage("premiumUnlocked") private var premiumUnlocked: Bool = false
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled: Bool = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = false
    @State private var avatarSelection: PhotosPickerItem? = nil
    
    // Notification settings
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("reminderType") private var reminderTypeRaw: String = ReminderType.specificTime.rawValue
    @AppStorage("reminderHour") private var reminderHour: Int = 18
    @AppStorage("reminderMinute") private var reminderMinute: Int = 0
    @AppStorage("reminderInterval") private var reminderInterval: Int = 4
    @AppStorage("preferredWorkoutMode") private var preferredWorkoutModeRaw: String = WorkoutMode.manual.rawValue
    @State private var showNotificationPermissionAlert = false
    @State private var showResetConfirmation = false
    @State private var showiCloudErrorAlert = false
    @State private var showiCloudUnavailableAlert = false
    
    // Device-dependent sizes
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var accentCircleSize: CGFloat {
        horizontalSizeClass == .compact ? 32 : 36
    }
    private var accentSpacing: CGFloat {
        horizontalSizeClass == .compact ? 8 : 12
    }
    
    private var reminderType: ReminderType {
        ReminderType(rawValue: reminderTypeRaw) ?? .specificTime
    }
    
    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = components.hour ?? 18
                reminderMinute = components.minute ?? 0
            }
        )
    }

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

                Section("Appearance") {
                    // Theme Picker
                    Picker("Theme", selection: $themeManager.theme) {
                        ForEach(AppTheme.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .id("theme-picker-\(themeManager.accentColor.rawValue)")
                    
                    // Accent Color Picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accent Color")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 0) {
                            ForEach(AccentColor.allCases) { accent in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        themeManager.accentColor = accent
                                    }
                                    // Reload widgets when accent color changes
                                    reloadWidgets()
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(accent.color)
                                            .frame(width: accentCircleSize, height: accentCircleSize)
                                        
                                        if themeManager.accentColor == accent {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: accentCircleSize * 0.4, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                if accent != AccentColor.allCases.last {
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                // Removed View Plan; reset moved into Edit Plan screen
                
                Section("Workout Reminders") {
                    Toggle("Enable Reminders", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            handleNotificationToggle(newValue)
                        }
                    
                    if notificationsEnabled {
                        Picker("Reminder Type", selection: $reminderTypeRaw) {
                            ForEach(ReminderType.allCases, id: \.rawValue) { type in
                                Text(type.rawValue).tag(type.rawValue)
                            }
                        }
                        .id("reminder-type-picker-\(themeManager.accentColor.rawValue)")
                        .onChange(of: reminderTypeRaw) { _, _ in
                            scheduleNotifications()
                        }
                        
                        if reminderType == .specificTime {
                            HStack {
                                Text("Reminder Time")
                                Spacer()
                                DatePicker("", selection: reminderTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .onChange(of: reminderHour) { _, _ in
                                        scheduleNotifications()
                                    }
                                    .onChange(of: reminderMinute) { _, _ in
                                        scheduleNotifications()
                                    }
                            }
                            
                        } else {
                            Picker("Reminder Interval", selection: $reminderInterval) {
                                Text("Every 4 hours").tag(4)
                                Text("Every 6 hours").tag(6)
                                Text("Every 8 hours").tag(8)
                            }
                            .id("reminder-interval-picker-\(themeManager.accentColor.rawValue)")
                            .onChange(of: reminderInterval) { _, _ in
                                scheduleNotifications()
                            }
                            
                            Text("You'll receive reminders throughout the day at regular intervals (8am, 12pm, 4pm, 8pm).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

            Section("iCloud Backup") {
                if !iCloudSyncService.isAvailable() {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("iCloud not available. Please sign in to iCloud in Settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Toggle("Enable iCloud Backup", isOn: Binding(
                        get: { iCloudSyncEnabled },
                        set: { newVal in
                            if newVal {
                                enableiCloudSync()
                            } else {
                                iCloudSyncEnabled = false
                            }
                        }
                    ))
                    .disabled(iCloudSync.isSyncing)
                    
                    if iCloudSync.isSyncing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Syncing...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else if let lastSync = iCloudSync.lastSyncDate {
                        Text("Last synced: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Backs up your workouts, plans, and preferences. Keeps 1 year on device, archives older data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

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

            Section("Data") {
                Button(role: .destructive, action: { showResetConfirmation = true }) {
                    Label("Reset All Data", systemImage: "trash")
                }
            }
            }
            .tint(themeManager.accentColor.color)
            .navigationTitle("Settings")
            .defaultScrollAnchor(.top)
            .scrollContentBackground(.hidden)
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
            .onAppear { 
                profile = ProfileStore.load()
                notificationManager.checkAuthorizationStatus()
            }
            .alert("Notification Permission Required", isPresented: $showNotificationPermissionAlert) {
                Button("Open Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable notifications in Settings to receive workout reminders.")
            }
            .alert("Reset All Data?", isPresented: $showResetConfirmation) {
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your workout sessions, plans, and profile data. This action cannot be undone.")
            }
            .alert("iCloud Sync Unavailable", isPresented: $showiCloudErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("iCloud backup requires a paid Apple Developer account. Without this, data cannot be synced to iCloud. Your data remains safely stored on your device.")
            }
            .onChange(of: iCloudSync.syncError) { _, error in
                if error != nil {
                    showiCloudErrorAlert = true
                }
            }
        }
    }

    private func resetAllData() {
        SessionStore.save([])
        PlanStore.delete()
        UserDefaults.standard.removeObject(forKey: "userProfile")
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(WorkoutMode.manual.rawValue, forKey: "preferredWorkoutMode")
        notificationManager.cancelAllReminders()
        notificationsEnabled = false
        profile = nil
        
        // Reset theme and accent to defaults
        themeManager.theme = .system
        themeManager.accentColor = .blue
    }
    
    // MARK: - Notification Helpers
    
    private func handleNotificationToggle(_ enabled: Bool) {
        if enabled {
            // Request permission if not already granted
            notificationManager.requestAuthorization { granted in
                if granted {
                    scheduleNotifications()
                } else {
                    // Permission denied, turn off toggle
                    DispatchQueue.main.async {
                        notificationsEnabled = false
                        showNotificationPermissionAlert = true
                    }
                }
            }
        } else {
            // Cancel all notifications
            notificationManager.cancelAllReminders()
        }
    }
    
    private func scheduleNotifications() {
        guard notificationsEnabled else { return }
        
        if reminderType == .specificTime {
            notificationManager.scheduleSpecificTimeReminder(hour: reminderHour, minute: reminderMinute)
        } else {
            notificationManager.scheduleIntervalReminders(intervalHours: reminderInterval)
        }
    }
    
    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #if DEBUG
        print("[SettingsView] 🔄 Reloading all widget timelines after accent color change")
        #endif
        #endif
    }
    
    // MARK: - iCloud Sync Helpers
    
    private func enableiCloudSync() {
        guard iCloudSyncService.isAvailable() else {
            showiCloudUnavailableAlert = true
            return
        }
        
        iCloudSyncEnabled = true
        
        // Perform initial sync
        Task {
            do {
                try await iCloudSync.syncAll()
            } catch {
                #if DEBUG
                print("[SettingsView] Error syncing to iCloud: \(error)")
                #endif
                await MainActor.run {
                    iCloudSyncEnabled = false
                }
            }
        }
    }
}


