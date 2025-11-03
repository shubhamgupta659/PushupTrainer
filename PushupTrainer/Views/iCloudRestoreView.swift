//
//  iCloudRestoreView.swift
//  PushupTrainer
//
//  View shown during onboarding if iCloud backup is available
//  Asks user to either restore from iCloud or start fresh
//

import SwiftUI

struct iCloudRestoreView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var iCloudSync = iCloudSyncService.shared
    
    @State private var hasICloudData: Bool = false
    @State private var isChecking: Bool = true
    @State private var isRestoring: Bool = false
    @State private var restoreError: String? = nil
    @State private var showErrorAlert: Bool = false
    
    let onRestore: () -> Void
    let onStartFresh: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: hasICloudData ? "icloud.and.arrow.down.fill" : "icloud.slash")
                .font(.system(size: 80))
                .foregroundStyle(themeManager.accentColor.color)
                .padding(.bottom, 20)
            
            // Title
            Text(hasICloudData ? "iCloud Backup Found" : "Welcome to Push-Up Trainer")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            
            // Description
            Text(hasICloudData ? 
                 "We found your workout data backed up in iCloud. Would you like to restore it?" :
                 "Set up your fitness journey with personalized goals.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if isChecking {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 20)
            } else if hasICloudData {
                VStack(spacing: 12) {
                    Button(action: restoreFromiCloud) {
                        HStack {
                            if isRestoring {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "icloud.and.arrow.down")
                            }
                            Text(isRestoring ? "Restoring..." : "Restore from iCloud")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.accentColor.color)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isRestoring)
                    
                    Button(action: onStartFresh) {
                        Text("Start Fresh")
                            .font(.headline)
                            .foregroundStyle(themeManager.accentColor.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(themeManager.accentColor.color, lineWidth: 2)
                            )
                    }
                    .disabled(isRestoring)
                    
                    Text("Starting fresh will not affect your iCloud backup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            } else {
                Button(action: onStartFresh) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.accentColor.color)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }
            
            Spacer()
        }
        .padding(20)
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
        .task {
            await checkForiCloudData()
        }
        .alert("Restore Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
            Button("Try Again") {
                restoreFromiCloud()
            }
        } message: {
            Text(restoreError ?? "Failed to restore from iCloud. Please try again.")
        }
    }
    
    private func checkForiCloudData() async {
        #if DEBUG
        print("[iCloudRestoreView] Checking for iCloud backup data...")
        #endif
        
        guard iCloudSyncService.isAvailable() else {
            #if DEBUG
            print("[iCloudRestoreView] iCloud not available")
            #endif
            isChecking = false
            return
        }
        
        // Check if there's any data in iCloud
        let store = NSUbiquitousKeyValueStore.default
        let hasData = store.object(forKey: "icloud_profile") != nil ||
                      store.object(forKey: "icloud_sessions") != nil ||
                      store.object(forKey: "icloud_plan") != nil
        
        #if DEBUG
        print("[iCloudRestoreView] Has iCloud data: \(hasData)")
        #endif
        
        await MainActor.run {
            hasICloudData = hasData
            isChecking = false
        }
    }
    
    private func restoreFromiCloud() {
        Task {
            isRestoring = true
            restoreError = nil
            
            do {
                #if DEBUG
                print("[iCloudRestoreView] Starting iCloud restore...")
                #endif
                
                // Merge data from iCloud
                try await iCloudSync.mergeFromiCloud()
                
                #if DEBUG
                print("[iCloudRestoreView] ✅ Restore complete")
                #endif
                
                await MainActor.run {
                    isRestoring = false
                    onRestore()
                }
            } catch {
                #if DEBUG
                print("[iCloudRestoreView] ❌ Restore error: \(error)")
                #endif
                
                await MainActor.run {
                    isRestoring = false
                    restoreError = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}

