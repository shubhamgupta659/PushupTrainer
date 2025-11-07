//
//  iCloudSyncService.swift
//  PushupTrainer
//
//  iCloud Backup & Sync Service
//  Handles:
//  - Syncing workout sessions, plans, profile, and preferences to iCloud
//  - Maintaining 1 year of local data, archiving older data to iCloud
//  - Handling iCloud storage full scenarios
//  - Merging data from iCloud on app launch
//

import Foundation
import Combine

class iCloudSyncService: ObservableObject {
    static let shared = iCloudSyncService()
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date? = nil
    @Published var syncError: String? = nil
    
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let oneYearInSeconds: TimeInterval = 365 * 24 * 60 * 60
    
    // Keys for iCloud storage
    enum iCloudKeys {
        static let sessions = "icloud_sessions"
        static let archivedSessions = "icloud_archived_sessions"
        static let plan = "icloud_plan"
        static let profile = "icloud_profile"
        static let preferences = "icloud_preferences"
        static let awards = "icloud_awards"
        static let lastSyncDate = "icloud_last_sync_date"
    }
    
    private init() {
        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleiCloudChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Sync Methods
    
    /// Sync all data to iCloud
    func syncAll() async throws {
        // Check if iCloud is available before attempting sync
        guard iCloudSyncService.isAvailable() else {
            #if DEBUG
            print("[iCloudSyncService] ⚠️ iCloud not available, skipping sync")
            #endif
            throw iCloudSyncError.syncFailed
        }
        
        DispatchQueue.main.async {
            self.isSyncing = true
            self.syncError = nil
        }
        
        do {
            try await syncSessions()
            try await syncPlan()
            try await syncProfile()
            try await syncPreferences()
            try await syncAwards()
            
            DispatchQueue.main.async {
                self.lastSyncDate = Date()
                self.isSyncing = false
            }
            
            #if DEBUG
            print("[iCloudSyncService] ✅ All data synced successfully")
            #endif
        } catch {
            DispatchQueue.main.async {
                self.syncError = error.localizedDescription
                self.isSyncing = false
            }
            throw error
        }
    }
    
    /// Merge iCloud data into local storage on app launch
    func mergeFromiCloud() async throws {
        #if DEBUG
        print("[iCloudSyncService] 🔄 Merging data from iCloud...")
        #endif
        
        try await mergeSessions()
        try await mergePlan()
        try await mergeProfile()
        try await mergePreferences()
        try await mergeAwards()
        
        DispatchQueue.main.async {
            self.lastSyncDate = self.ubiquitousStore.object(forKey: iCloudKeys.lastSyncDate) as? Date
        }
        
        #if DEBUG
        print("[iCloudSyncService] ✅ Merge from iCloud complete")
        #endif
    }
    
    // MARK: - Session Sync
    
    private func syncSessions() async throws {
        let localSessions = SessionStore.load()
        let oneYearAgo = Date().addingTimeInterval(-oneYearInSeconds)
        
        // Split sessions: keep < 1 year locally, archive older to iCloud
        let recentSessions = localSessions.filter { $0.date >= oneYearAgo }
        let archivedSessions = localSessions.filter { $0.date < oneYearAgo }
        
        // Encode sessions
        guard let recentData = try? JSONEncoder().encode(recentSessions) else {
            throw iCloudSyncError.encodingFailed
        }
        
        // Read existing archived sessions from iCloud
        var allArchivedSessions = [WorkoutSession]()
        if let archivedData = ubiquitousStore.data(forKey: iCloudKeys.archivedSessions),
           let existingArchived = try? JSONDecoder().decode([WorkoutSession].self, from: archivedData) {
            allArchivedSessions = existingArchived
        }
        
        // Merge archived sessions (avoid duplicates by ID)
        let sessionIDs = Set(allArchivedSessions.map { $0.id })
        for session in archivedSessions {
            if !sessionIDs.contains(session.id) {
                allArchivedSessions.append(session)
            }
        }
        
        // Sort archived by date (oldest first)
        allArchivedSessions.sort { $0.date < $1.date }
        
        guard let allArchivedData = try? JSONEncoder().encode(allArchivedSessions) else {
            throw iCloudSyncError.encodingFailed
        }
        
        // Save to iCloud
        ubiquitousStore.set(recentData, forKey: iCloudKeys.sessions)
        ubiquitousStore.set(allArchivedData, forKey: iCloudKeys.archivedSessions)
        
        // Save recent sessions locally (remove older ones)
        SessionStore.save(recentSessions)
        
        let success = ubiquitousStore.synchronize()
        #if DEBUG
        print("[iCloudSyncService] synchronize() result: \(success)")
        if !success {
            print("[iCloudSyncService] ⚠️ synchronize() failed for sessions")
        }
        #endif
        if !success {
            throw iCloudSyncError.syncFailed
        }
        
        #if DEBUG
        print("[iCloudSyncService] Sessions: \(recentSessions.count) local, \(allArchivedSessions.count) archived")
        #endif
    }
    
    private func mergeSessions() async throws {
        var localSessions = SessionStore.load()
        let localSessionIDs = Set(localSessions.map { $0.id })
        
        // Merge recent sessions from iCloud
        if let recentData = ubiquitousStore.data(forKey: iCloudKeys.sessions),
           let iCloudRecentSessions = try? JSONDecoder().decode([WorkoutSession].self, from: recentData) {
            for session in iCloudRecentSessions {
                if !localSessionIDs.contains(session.id) {
                    localSessions.append(session)
                }
            }
        }
        
        // Merge archived sessions from iCloud (only if local has < 1 year)
        let oneYearAgo = Date().addingTimeInterval(-oneYearInSeconds)
        let localRecentCount = localSessions.filter { $0.date >= oneYearAgo }.count
        if localRecentCount < 30 { // Only merge if we have very few local sessions
            if let archivedData = ubiquitousStore.data(forKey: iCloudKeys.archivedSessions),
               let iCloudArchivedSessions = try? JSONDecoder().decode([WorkoutSession].self, from: archivedData) {
                // Only merge sessions from the last year
                for session in iCloudArchivedSessions {
                    if session.date >= oneYearAgo && !localSessionIDs.contains(session.id) {
                        localSessions.append(session)
                    }
                }
            }
        }
        
        // Sort by date and save
        localSessions.sort { $0.date < $1.date }
        SessionStore.save(localSessions)
        
        #if DEBUG
        print("[iCloudSyncService] Merged \(localSessions.count) sessions")
        #endif
    }
    
    // MARK: - Plan Sync
    
    private func syncPlan() async throws {
        if let plan = PlanStore.load(),
           let data = try? JSONEncoder().encode(plan) {
            ubiquitousStore.set(data, forKey: iCloudKeys.plan)
            if !ubiquitousStore.synchronize() {
                throw iCloudSyncError.syncFailed
            }
        }
    }
    
    private func mergePlan() async throws {
        // Only merge if local plan is nil
        if PlanStore.load() == nil,
           let data = ubiquitousStore.data(forKey: iCloudKeys.plan),
           let plan = try? JSONDecoder().decode(WorkoutPlan.self, from: data) {
            PlanStore.save(plan)
        }
    }
    
    // MARK: - Profile Sync
    
    private func syncProfile() async throws {
        if let profile = ProfileStore.load(),
           let data = try? JSONEncoder().encode(profile) {
            ubiquitousStore.set(data, forKey: iCloudKeys.profile)
            if !ubiquitousStore.synchronize() {
                throw iCloudSyncError.syncFailed
            }
        }
    }
    
    private func mergeProfile() async throws {
        // Merge profile: prefer more recent
        if let localProfile = ProfileStore.load(),
           let iCloudData = ubiquitousStore.data(forKey: iCloudKeys.profile),
           let iCloudProfile = try? JSONDecoder().decode(UserProfile.self, from: iCloudData) {
            // Keep the more recently updated profile
            if iCloudProfile.updatedAt > localProfile.updatedAt {
                ProfileStore.save(iCloudProfile)
                #if DEBUG
                print("[iCloudSyncService] Using iCloud profile (more recent)")
                #endif
            }
        } else if ProfileStore.load() == nil,
                  let data = ubiquitousStore.data(forKey: iCloudKeys.profile),
                  let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            ProfileStore.save(profile)
            #if DEBUG
            print("[iCloudSyncService] Restored profile from iCloud")
            #endif
        }
    }
    
    // MARK: - Preferences Sync
    
    private func syncPreferences() async throws {
        var prefs: [String: Any] = [:]
        
        // Collect all user preferences
        if let theme = UserDefaults.standard.string(forKey: "appTheme") {
            prefs["appTheme"] = theme
        }
        if let accentColor = UserDefaults.standard.string(forKey: "accentColor") {
            prefs["accentColor"] = accentColor
        }
        prefs["notificationsEnabled"] = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        if let reminderType = UserDefaults.standard.string(forKey: "reminderType") {
            prefs["reminderType"] = reminderType
        }
        prefs["reminderHour"] = UserDefaults.standard.integer(forKey: "reminderHour")
        prefs["reminderMinute"] = UserDefaults.standard.integer(forKey: "reminderMinute")
        prefs["reminderInterval"] = UserDefaults.standard.integer(forKey: "reminderInterval")
        prefs["preferredWorkoutMode"] = UserDefaults.standard.string(forKey: "preferredWorkoutMode") ?? WorkoutMode.manual.rawValue
        prefs["premiumUnlocked"] = UserDefaults.standard.bool(forKey: "premiumUnlocked")
        
        guard let data = try? JSONSerialization.data(withJSONObject: prefs, options: []) else {
            throw iCloudSyncError.encodingFailed
        }
        
        ubiquitousStore.set(data, forKey: iCloudKeys.preferences)
        
        if !ubiquitousStore.synchronize() {
            throw iCloudSyncError.syncFailed
        }
    }
    
    private func mergePreferences() async throws {
        if let data = ubiquitousStore.data(forKey: iCloudKeys.preferences),
           let prefs = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            // Only apply preferences if local values are defaults
            for (key, value) in prefs {
                if UserDefaults.standard.object(forKey: key) == nil {
                    UserDefaults.standard.set(value, forKey: key)
                }
            }
        }
    }

    // MARK: - Awards Sync

    private func syncAwards() async throws {
        let progress = AwardStore.loadProgress()
        guard let data = try? JSONEncoder().encode(progress) else {
            throw iCloudSyncError.encodingFailed
        }

        ubiquitousStore.set(data, forKey: iCloudKeys.awards)

        if !ubiquitousStore.synchronize() {
            throw iCloudSyncError.syncFailed
        }
    }

    private func mergeAwards() async throws {
        guard let data = ubiquitousStore.data(forKey: iCloudKeys.awards),
              let cloudProgress = try? JSONDecoder().decode(AwardProgress.self, from: data) else {
            return
        }

        var localProgress = AwardStore.loadProgress()
        let originalProgress = localProgress
        localProgress.unlockedAwardIds.formUnion(cloudProgress.unlockedAwardIds)
        localProgress.lastCheckedDate = max(localProgress.lastCheckedDate, cloudProgress.lastCheckedDate)

        // Only save if there are new awards or a more recent timestamp
        if localProgress.unlockedAwardIds != originalProgress.unlockedAwardIds || localProgress.lastCheckedDate != originalProgress.lastCheckedDate {
            AwardStore.saveProgress(localProgress)
        }
    }
    
    // MARK: - iCloud Change Handling
    
    @objc private func handleiCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }
        
        #if DEBUG
        print("[iCloudSyncService] ⚠️ iCloud change detected, reason: \(reason)")
        #endif
        
        // Reason 0: Initial sync, 1: Server sync, 2: Local change, 3: Quota violation
        if reason == 3 { // Quota violation
            DispatchQueue.main.async {
                self.syncError = "iCloud storage is full. Please free up space or risk losing older data."
            }
        } else if reason == 0 || reason == 1 {
            // Merge changes from iCloud
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.mergeFromiCloud()
                } catch {
                    #if DEBUG
                    print("[iCloudSyncService] Error merging from iCloud: \(error)")
                    #endif
                }
            }
        }
    }
    
    // MARK: - Check iCloud Availability
    
    static func isAvailable() -> Bool {
        let available = FileManager.default.ubiquityIdentityToken != nil
        #if DEBUG
        print("[iCloudSyncService] isAvailable: \(available), ubiquityIdentityToken: \(FileManager.default.ubiquityIdentityToken != nil ? "present" : "nil")")
        #endif
        return available
    }
}

// MARK: - Error Types

enum iCloudSyncError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case syncFailed
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode data for iCloud"
        case .decodingFailed:
            return "Failed to decode data from iCloud"
        case .syncFailed:
            return "Failed to synchronize with iCloud"
        case .quotaExceeded:
            return "iCloud storage is full. Please free up space."
        }
    }
}
