//
//  AwardsView.swift
//  PushupTrainer
//

import SwiftUI

struct AwardsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var awards: [Award] = []
    @State private var selectedCategory: AwardCategory?
    @State private var selectedAward: Award?
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary card
                    summaryCard
                    
                    // Category tabs
                    categoryTabs
                    
                    // Awards grid
                    if let category = selectedCategory {
                        awardsGrid(for: category)
                    } else {
                        // Show all categories
                        ForEach(AwardCategory.allCases) { category in
                            categorySection(category)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Awards")
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
                refreshAwards()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionsUpdated"))) { _ in
                refreshAwards()
            }
            .sheet(isPresented: Binding(
                get: { showShareSheet && shareImage != nil && selectedAward != nil },
                set: { newValue in
                    if !newValue {
                        showShareSheet = false
                        // Reset after dismissal
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            shareImage = nil
                            selectedAward = nil
                        }
                    }
                }
            )) {
                if let image = shareImage, let award = selectedAward {
                    ShareSheetView(image: image, award: award)
                }
            }
        }
    }
    
    private var summaryCard: some View {
        let stats = AwardService.shared.calculateStats()
        let unlockedCount = awards.filter { $0.isUnlocked }.count
        let totalCount = awards.count
        
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(themeManager.accentColor.color)
                Text("\(unlockedCount) / \(totalCount)")
                    .font(.title.bold())
                Text("Awards Unlocked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(themeManager.accentColor.color)
                        .frame(width: geometry.size.width * CGFloat(unlockedCount) / CGFloat(max(1, totalCount)), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            // Quick stats
            HStack(spacing: 20) {
                VStack {
                    Text("\(stats.totalReps)")
                        .font(.headline)
                    Text("Total Reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                VStack {
                    Text("\(stats.currentStreak)")
                        .font(.headline)
                    Text("Day Streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                VStack {
                    Text("\(stats.totalWorkouts)")
                        .font(.headline)
                    Text("Workouts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
        )
    }
    
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation {
                        selectedCategory = nil
                    }
                }) {
                    Text("All")
                        .font(.subheadline.bold())
                        .foregroundColor(selectedCategory == nil ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == nil ?
                            AnyShapeStyle(themeManager.accentColor.color) :
                            AnyShapeStyle(Color.gray.opacity(0.2))
                        )
                        .cornerRadius(20)
                }
                
                ForEach(AwardCategory.allCases) { category in
                    Button(action: {
                        withAnimation {
                            selectedCategory = category
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: category.iconName)
                                .font(.caption)
                            Text(category.displayName)
                                .font(.subheadline.bold())
                        }
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category ?
                            AnyShapeStyle(category.color) :
                            AnyShapeStyle(Color.gray.opacity(0.2))
                        )
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func categorySection(_ category: AwardCategory) -> some View {
        let categoryAwards = awards.filter { $0.category == category }
        guard !categoryAwards.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: category.iconName)
                        .foregroundStyle(category.color)
                    Text(category.displayName)
                        .font(.headline)
                }
                .padding(.horizontal, 4)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(categoryAwards) { award in
                        AwardCard(award: award, onTap: {
                            if award.isUnlocked {
                                selectedAward = award
                                generateShareImage(for: award)
                            }
                        })
                    }
                }
            }
            .padding(.vertical, 8)
        )
    }
    
    private func awardsGrid(for category: AwardCategory) -> some View {
        let categoryAwards = awards.filter { $0.category == category }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.iconName)
                    .foregroundStyle(category.color)
                Text(category.displayName)
                    .font(.headline)
            }
            .padding(.horizontal, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(categoryAwards) { award in
                    AwardCard(award: award, onTap: {
                        if award.isUnlocked {
                            selectedAward = award
                            generateShareImage(for: award)
                        }
                    })
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func refreshAwards() {
        awards = AwardService.shared.updateAwardsProgress()
    }
    
    private func generateShareImage(for award: Award) {
        #if DEBUG
        print("[AwardsView] 🎯 Generating share image for award: \(award.title)")
        #endif
        
        // Set selected award first
        selectedAward = award
        
        // Use Task to ensure view rendering happens asynchronously
        Task { @MainActor in
            let profile = ProfileStore.load()
            let stats = AwardService.shared.calculateStats()
            
            #if DEBUG
            print("[AwardsView] ✅ Profile loaded: \(profile?.displayName ?? "nil")")
            print("[AwardsView] ✅ Stats: \(stats.totalReps) reps, \(stats.totalWorkouts) workouts, \(stats.currentStreak) streak")
            print("[AwardsView] ✅ Accent color: \(themeManager.accentColor.color)")
            #endif
            
            // Create share poster image
            let posterView = AwardSharePoster(
                award: award,
                profile: profile,
                stats: stats,
                accentColor: themeManager.accentColor.color
            )
            
            // Create renderer and configure it
            let renderer = ImageRenderer(content: posterView)
            renderer.scale = 3.0 // High resolution
            
            #if DEBUG
            print("[AwardsView] 🖼️ ImageRenderer created, attempting to render...")
            #endif
            
            // Try multiple times with increasing delays
            var image: UIImage? = nil
            let delays: [UInt64] = [100_000_000, 200_000_000, 300_000_000] // 0.1s, 0.2s, 0.3s
            
            for (index, delay) in delays.enumerated() {
                try? await Task.sleep(nanoseconds: delay)
                
                image = renderer.uiImage
                
                #if DEBUG
                print("[AwardsView] 🔄 Attempt \(index + 1): Image is \(image != nil ? "✅ ready" : "❌ nil")")
                #endif
                
                if image != nil {
                    break
                }
            }
            
            // Final attempt - sometimes ImageRenderer needs a different approach
            if image == nil {
                #if DEBUG
                print("[AwardsView] ⚠️ Final attempt - creating new renderer...")
                #endif
                
                // Try creating a new renderer
                let newRenderer = ImageRenderer(content: posterView)
                newRenderer.scale = 3.0
                
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                image = newRenderer.uiImage
                
                #if DEBUG
                print("[AwardsView] 🔄 Final attempt result: Image is \(image != nil ? "✅ ready" : "❌ nil")")
                #endif
            }
            
            // Only show sheet if we have a valid image
            if let finalImage = image {
                #if DEBUG
                print("[AwardsView] ✅ Success! Image size: \(finalImage.size)")
                #endif
                shareImage = finalImage
                showShareSheet = true
            } else {
                #if DEBUG
                print("[AwardsView] ❌ Failed to generate image after all attempts")
                #endif
                // Reset if failed and don't show sheet
                selectedAward = nil
                shareImage = nil
                showShareSheet = false
            }
        }
    }
}

struct AwardCard: View {
    let award: Award
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(award.isUnlocked ? award.category.color.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    if award.isUnlocked {
                        Image(systemName: award.iconName)
                            .font(.system(size: 36))
                            .foregroundStyle(award.category.color)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                        
                        // Progress ring
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: award.progress)
                            .stroke(award.category.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 80, height: 80)
                    }
                }
                
                Text(award.title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                if !award.isUnlocked {
                    Text("\(award.progressPercentage)%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(award.isUnlocked ? Color.gray.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AwardSharePoster: View {
    let award: Award
    let profile: UserProfile?
    let stats: (totalReps: Int, totalWorkouts: Int, currentStreak: Int, longestStreak: Int, perfectDays: Int, maxRepsInSession: Int, totalCalories: Double)
    let accentColor: Color
    
    var body: some View {
        ZStack {
            // Light background to ensure it renders bright for Instagram
            Color.white
                .ignoresSafeArea()
            
            // Background gradient with more vibrant colors
            LinearGradient(
                colors: [
                    accentColor.opacity(0.3),
                    accentColor.opacity(0.15),
                    accentColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Decorative circles in background
            Circle()
                .fill(accentColor.opacity(0.08))
                .frame(width: 800, height: 800)
                .offset(x: -400, y: -600)
            
            Circle()
                .fill(accentColor.opacity(0.06))
                .frame(width: 600, height: 600)
                .offset(x: 500, y: 700)
            
            VStack(spacing: 50) {
                Spacer()
                    .frame(height: 80)
                
                // Award icon - much bigger
                ZStack {
                    Circle()
                        .fill(award.category.color.opacity(0.25))
                        .frame(width: 400, height: 400)
                    
                    // Outer glow effect
                    Circle()
                        .stroke(award.category.color.opacity(0.3), lineWidth: 8)
                        .frame(width: 400, height: 400)
                    
                    Image(systemName: award.iconName)
                        .font(.system(size: 200, weight: .bold))
                        .foregroundStyle(award.category.color)
                }
                .shadow(color: award.category.color.opacity(0.3), radius: 30, x: 0, y: 10)
                
                // Award title - much bigger
                Text(award.title)
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Award description - bigger
                Text(award.description)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(Color(white: 0.3))
                    .multilineTextAlignment(.center)
                
                Spacer()
                
                // User info section - much bigger
                VStack(spacing: 30) {
                    if let displayName = profile?.displayName, !displayName.isEmpty {
                        Text("Achieved by \(displayName)")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.bottom, 10)
                    }
                    
                    // Stats in a more prominent layout with better contrast
                    HStack(spacing: 60) {
                        VStack(spacing: 12) {
                            Text("\(formatNumber(stats.totalReps))")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black)
                            Text("Total Reps")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(Color(white: 0.4))
                        }
                        
                        VStack(spacing: 12) {
                            Text("\(stats.currentStreak)")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black)
                            Text("Day Streak")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(Color(white: 0.4))
                        }
                        
                        VStack(spacing: 12) {
                            Text("\(stats.totalWorkouts)")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black)
                            Text("Workouts")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(Color(white: 0.4))
                        }
                    }
                    .padding(.vertical, 40)
                    .padding(.horizontal, 50)
                }
                .padding(.bottom, 60)
                
                // App name with actual app icon
                HStack(spacing: 20) {
                    // Actual app icon from bundle - smaller size
                    if let appIcon = getAppIcon() {
                        Image(uiImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
                    } else {
                        // Fallback to system icon if app icon not found
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(accentColor)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: accentColor.opacity(0.4), radius: 15, x: 0, y: 5)
                    }
                    
                    Text("Pushup Trainer")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Color.black)
                }
                .padding(.bottom, 50)
            }
            .padding(60)
        }
        .frame(width: 1200, height: 1600) // Square format for social media
        .preferredColorScheme(.light) // Force light mode for consistent rendering
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func getAppIcon() -> UIImage? {
        // Try to get the app icon from the bundle
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let iconFileName = iconFiles.last {
            return UIImage(named: iconFileName)
        }
        
        // Fallback: try common app icon names
        if let icon = UIImage(named: "AppIcon") {
            return icon
        }
        
        if let icon = UIImage(named: "app_icon") {
            return icon
        }
        
        // Try to get icon from asset catalog
        if let icon = UIImage(named: "AppIcon", in: Bundle.main, compatibleWith: nil) {
            return icon
        }
        
        return nil
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    let image: UIImage
    let award: Award
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [image, "🏆 \(award.title) - \(award.description)\n\n#PushupTrainer"],
            applicationActivities: nil
        )
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

