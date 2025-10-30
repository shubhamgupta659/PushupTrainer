//
//  HomeView.swift
//  PushupTrainer
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var profile: UserProfile? = ProfileStore.load()
    @State private var sessions: [WorkoutSession] = SessionStore.load()
    @State private var plan: WorkoutPlan? = PlanStore.load()
    @State private var selectedPeriod: TimePeriod = .day
    @AppStorage("hasCompletedFirstWorkout") private var hasCompletedFirstWorkout: Bool = false
    
    enum TimePeriod: String, CaseIterable {
        case day = "D"
        case week = "W"
        case month = "M"
        case year = "Y"
    }

    var body: some View {
        NavigationStack {
            let isLight = shouldUseLightTheme
            ZStack {
                // Full-screen gradient background
                (isLight ? LinearGradient(gradient: Gradient(colors: [Color.white, Color(white: 0.95)]), startPoint: .top, endPoint: .bottom)
                         : LinearGradient(gradient: Gradient(colors: [Color(red:0.05, green:0.08, blue:0.18), Color(red:0.18, green:0.06, blue:0.20)]), startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
                .id(themeManager.theme)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Welcome screen for first-time users
                        if !hasCompletedFirstWorkout {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(welcomeText())
                                    .font(.title2.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Let's get started")
                                    .font(.largeTitle.bold())
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Complete your first workout to see your progress here")
                                    .foregroundStyle(.secondary)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.top, 30)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            // Welcome message with username
                            Text(welcomeText())
                                .font(.title2.bold())
                                .padding(.vertical, 8)
                            
                            // Title and Period Selector
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Summary Stats")
                            .font(.largeTitle.bold())

                                // Period Selector
                                HStack(spacing: 0) {
                                    ForEach(TimePeriod.allCases, id: \.self) { period in
                                        Button(action: { selectedPeriod = period }) {
                                            Text(period.rawValue)
                                .font(.headline)
                                                .foregroundColor(selectedPeriod == period ? .white : .primary)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(
                                                    selectedPeriod == period ?
                                                    AnyShapeStyle(Color.purple.opacity(0.8)) :
                                                    AnyShapeStyle(Color.clear)
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                }
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            
                            // Total Stats
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TOTAL")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formattedTotalReps())
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundStyle(.purple)
                                Text(periodLabel())
                                    .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                            .padding(.vertical, 4)
                            
                            // Bar Graph
                            let barData = getBarGraphData()
                            if !barData.isEmpty {
                                BarGraphView(data: barData, maxValue: getMaxValue(from: barData))
                                    .frame(height: 180)
                                    .padding(.vertical, 4)
                            }
                            
                            // Weekly Ring Completion
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Weekly Progress")
                                .font(.headline)
                                
                                WeeklyRingView(plan: plan, selectedDate: nil)
                        }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Extra padding for floating button
                }
                
                // Removed start button on Home as requested
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("").font(.headline) } }
            .background(Color.clear)
            .onAppear {
                refreshData()
            }
        }
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
    
    private func welcomeText() -> String {
        let name = (profile?.displayName?.isEmpty == false) ? (profile?.displayName ?? "User") : "User"
        return "Welcome \(name)"
    }
    
    private func refreshData() {
        hasCompletedFirstWorkout = !sessions.isEmpty
        sessions = SessionStore.load()
        plan = PlanStore.load()
        if !hasCompletedFirstWorkout && !sessions.isEmpty {
            hasCompletedFirstWorkout = true
        }
    }
    
    private func formattedTotalReps() -> String {
        let reps = getTotalRepsForPeriod()
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: reps)) ?? "0"
    }
    
    private func periodLabel() -> String {
        switch selectedPeriod {
        case .day: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }
    
    private func getTotalRepsForPeriod() -> Int {
        let filteredSessions = getFilteredSessionsForPeriod()
        return filteredSessions.reduce(0) { $0 + $1.reps }
    }

    private func getFilteredSessionsForPeriod() -> [WorkoutSession] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .day:
            let startOfDay = calendar.startOfDay(for: now)
            return sessions.filter { $0.date >= startOfDay }
            
        case .week:
            guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
                return []
            }
            return sessions.filter { $0.date >= startOfWeek }
            
        case .month:
            guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
                return []
            }
            return sessions.filter { $0.date >= startOfMonth }
            
        case .year:
            guard let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) else {
                return []
            }
            return sessions.filter { $0.date >= startOfYear }
        }
    }
    
    private func getBarGraphData() -> [BarData] {
        let filteredSessions = getFilteredSessionsForPeriod()
        
        switch selectedPeriod {
        case .day:
            return getHourlyData(for: filteredSessions)
        case .week:
            return getDailyData(for: filteredSessions, showDayNames: true)
        case .month:
            return getDailyData(for: filteredSessions, showDayNames: false)
        case .year:
            return getMonthlyData(for: filteredSessions)
        }
    }
    
    private func getHourlyData(for sessions: [WorkoutSession]) -> [BarData] {
        var hourlyReps: [Int: Int] = [:]
        let calendar = Calendar.current
        
        for session in sessions {
            let hour = calendar.component(.hour, from: session.date)
            hourlyReps[hour, default: 0] += session.reps
        }
        
        // Create data for every 6 hours to keep it manageable
        return stride(from: 0, to: 24, by: 6).map { hour in
            let reps = hourlyReps[hour] ?? 0
            let label = formatHourLabel(hour)
            return BarData(label: label, value: reps)
        }
    }

    private func getDailyData(for sessions: [WorkoutSession], showDayNames: Bool) -> [BarData] {
        let calendar = Calendar.current
        var dailyReps: [Date: Int] = [:]
        
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.date)
            dailyReps[dayStart, default: 0] += session.reps
        }
        
        let allDays = Array(dailyReps.keys).sorted()
        if allDays.isEmpty {
            return []
        }
        
        let startDate = allDays.first!
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        
        // Limit to last 7 days for weekly, 10 for monthly
        let displayDays = showDayNames ? min(daysSinceStart + 1, 7) : min(daysSinceStart + 1, 10)
        
        var result: [BarData] = []
        for i in 0..<displayDays {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                let reps = dailyReps[date] ?? 0
                let label: String
                if showDayNames {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "E" // Single letter day name
                    label = formatter.string(from: date)
                } else {
                    label = "\(calendar.component(.day, from: date))"
                }
                result.append(BarData(label: label, value: reps))
            }
        }
        
        return result
    }
    
    private func getMonthlyData(for sessions: [WorkoutSession]) -> [BarData] {
        let calendar = Calendar.current
        var monthlyReps: [Int: Int] = [:]
        
        for session in sessions {
            let month = calendar.component(.month, from: session.date)
            monthlyReps[month, default: 0] += session.reps
        }
        
        let monthNames = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
        return (1...12).map { month in
            BarData(label: monthNames[month - 1], value: monthlyReps[month] ?? 0)
        }
    }
    
    private func formatHourLabel(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }

    private func getMaxValue(from data: [BarData]) -> Int {
        let maxValue = data.map { $0.value }.max() ?? 0
        return max(maxValue, 1) // Minimum of 1 to show some visualization
    }
}

// MARK: - Supporting Views

struct BarData {
    let label: String
    let value: Int
}

struct BarGraphView: View {
    let data: [BarData]
    let maxValue: Int
    
    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height - 35
                
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, bar in
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.purple)
                                .frame(height: barHeight(for: bar.value, maxHeight: height))
                            
                            Spacer(minLength: 0)
                        }
                        .frame(width: max(8, (width - CGFloat(data.count - 1) * 3) / CGFloat(data.count)))
                    }
                }
            }
            .frame(height: 145)
            
            HStack(spacing: 3) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, bar in
                    Text(bar.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(height: 25)
        }
    }
    
    private func barHeight(for value: Int, maxHeight: CGFloat) -> CGFloat {
        guard maxValue > 0, value > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxValue) * maxHeight
    }
}

struct WeeklyRingView: View {
    let plan: WorkoutPlan?
    let selectedDate: Date?
    @State private var refreshTrigger = UUID()
    
    var body: some View {
        let weekDays = getWeekDays()
        
        HStack(spacing: 8) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 4) {
                    // Day label
                    Text(day.dayName)
                        .font(.caption2)
                        .foregroundStyle(day.isToday ? .white : .secondary)
                    
                    // Three rings with total reps
                    NavigationLink(destination: CalendarView()) {
                        ZStack {
                            // Background circles
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 2.5)
                            
                            // Outer ring (red) - represents achieving goal
                            Circle()
                                .trim(from: 0, to: day.repsRing)
                                .stroke(day.repsRing >= 1.0 ? Color.red : Color.red.opacity(0.3), lineWidth: 2.5)
                                .rotationEffect(.degrees(-90))
                            
                            // Middle ring (green) - workout completion
                            Circle()
                                .trim(from: 0, to: day.completionRing)
                                .stroke(day.completionRing >= 1.0 ? Color.green : Color.green.opacity(0.3), lineWidth: 2.5)
                                .rotationEffect(.degrees(-90))
                            
                            // Inner ring (blue) - extra achievement
                            Circle()
                                .trim(from: 0, to: day.extraRing)
                                .stroke(day.extraRing >= 1.0 ? Color.blue : Color.blue.opacity(0.3), lineWidth: 2.5)
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 45, height: 45)
                        .overlay(
                            Circle()
                                .strokeBorder(day.isToday ? Color.white : Color.clear, lineWidth: 1.5)
                                .background(
                                    Circle()
                                        .fill(day.isToday ? Color.red.opacity(0.5) : Color.clear)
                                )
                        )
                        .overlay(
                            Text(day.repsText)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(day.isToday ? .white : .primary)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .id(refreshTrigger)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionsUpdated"))) { _ in
            refreshTrigger = UUID()
        }
    }

    private func getWeekDays() -> [WeekDayData] {
        let calendar = Calendar.current
        let now = Date()
        let sessions = SessionStore.load()

        // Start week on Monday explicitly
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 2 // Monday
        guard let weekStart = calendar.date(from: comps) else { return createEmptyWeek() }

        let weekDayNames = ["M", "T", "W", "T", "F", "S", "S"]
        var result: [WeekDayData] = []
        
        for i in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: i, to: weekStart) else {
                continue
            }
            
            let isToday = calendar.isDateInToday(dayDate)
            let dayStart = calendar.startOfDay(for: dayDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }
            
            let daySessions = sessions.filter { $0.date >= dayStart && $0.date < dayEnd }
            // Prefer the session's captured target, otherwise use plan's day target or global plan target
            let capturedTarget = daySessions.compactMap { $0.targetRepsAtStart }.last
            let planDayTarget = plan?.days.first(where: { calendar.isDate($0.completedDate ?? dayDate, inSameDayAs: dayDate) })?.targetReps
            let fallbackPlanTarget = plan?.targetReps
            let targetReps = max(1, capturedTarget ?? planDayTarget ?? fallbackPlanTarget ?? 20)
            let dayReps = daySessions.reduce(0) { $0 + $1.reps }
            
            // Ring 1: Reps progress (only fill if goal is actually met)
            let ring1 = min(1.0, Double(dayReps) / Double(targetReps))
            
            // Ring 2: Workout completion (only if there's a workout)
            let ring2 = daySessions.count > 0 ? 1.0 : 0.0
            
            // Ring 3: Extra achievement (2x target)
            let ring3 = min(1.0, Double(dayReps) / Double(targetReps * 2))
            
            // Display total reps in center
            let repsText = dayReps > 0 ? "\(dayReps)" : ""
            
            result.append(WeekDayData(
                dayName: weekDayNames[i],
                isToday: isToday,
                repsRing: ring1,
                completionRing: ring2,
                extraRing: ring3,
                repsText: repsText
            ))
        }
        
        return result.isEmpty ? createEmptyWeek() : result
    }
    
    private func createEmptyWeek() -> [WeekDayData] {
        let calendar = Calendar.current
        let now = Date()
        let weekDayNames = ["M", "T", "W", "T", "F", "S", "S"]
        let currentDayOfWeek = calendar.component(.weekday, from: now) - 1
        let adjustedDayOfWeek = (currentDayOfWeek + 6) % 7 // Convert to Monday-based week
        
        return (0..<7).map { i in
            let dayName = weekDayNames[i]
            let isToday = i == adjustedDayOfWeek
            return WeekDayData(dayName: dayName, isToday: isToday, repsRing: 0.0, completionRing: 0.0, extraRing: 0.0, repsText: "")
    }
}
}

struct WeekDayData {
    let dayName: String
    let isToday: Bool
    let repsRing: Double
    let completionRing: Double
    let extraRing: Double
    let repsText: String
}
