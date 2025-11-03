//
//  HomeView.swift
//  PushupTrainer
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

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
                        
                        // Title
                        Text("Activity Overview")
                            .font(.largeTitle.bold())
                            .padding(.bottom, 4)
                        
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
                                            AnyShapeStyle(themeManager.accentColor.color.opacity(0.8)) :
                                            AnyShapeStyle(Color.clear)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.bottom, 8)
                        
                        // Total Stats - Three Cards
                        HStack(spacing: 12) {
                            // Total Reps
                            VStack(alignment: .center, spacing: 8) {
                                Image(systemName: "number.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(themeManager.accentColor.color)
                                Text(formattedTotalReps())
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("Total Reps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(themeManager.accentColor.color.opacity(0.1))
                            )
                            
                            // Total Workouts
                            VStack(alignment: .center, spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .font(.title2)
                                    .foregroundStyle(themeManager.accentColor.color)
                                Text("\(getTotalWorkoutsForPeriod())")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("Workouts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(themeManager.accentColor.color.opacity(0.1))
                            )
                            
                            // Total Calories
                            VStack(alignment: .center, spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.title2)
                                    .foregroundStyle(themeManager.accentColor.color)
                                Text(formattedTotalCalories())
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("Calories")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(themeManager.accentColor.color.opacity(0.1))
                            )
                        }
                        .padding(.vertical, 4)
                        
                        // Bar Graph
                        let barData = getBarGraphData()
                        let maxVal = getMaxValue(from: barData)
                        if !barData.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Breakdown")
                                    .font(.headline)
                                BarGraphView(data: barData, maxValue: maxVal)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Weekly Ring Completion
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This Week")
                                .font(.headline)
                            
                            WeeklyRingView(plan: plan, selectedDate: nil)
                        }
                        .padding(.vertical, 4)

                        // Weekly Calories Chart
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calories Burned")
                                .font(.headline)
                            
                            WeeklyCaloriesChart(sessions: sessions)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Extra padding for floating button
            }
            .defaultScrollAnchor(.top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("").font(.headline) } }
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
                refreshData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionsUpdated"))) { _ in
                refreshData()
            }
        }
    }
    
    private func welcomeText() -> String {
        let name = (profile?.displayName?.isEmpty == false) ? (profile?.displayName ?? "User") : "User"
        return "Welcome \(name)"
    }
    
    private func refreshData() {
        profile = ProfileStore.load()
        sessions = SessionStore.load()
        plan = PlanStore.load()
        
        #if DEBUG
        print("[HomeView] Refreshed data: \(sessions.count) sessions, plan exists: \(plan != nil)")
        if !sessions.isEmpty {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let todaySessions = sessions.filter { calendar.startOfDay(for: $0.date) == today }
            print("[HomeView] Today's sessions: \(todaySessions.count)")
            for session in todaySessions {
                print("  - Session: \(session.reps) reps at \(session.date)")
            }
        }
        #endif
        
        hasCompletedFirstWorkout = !sessions.isEmpty
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
    
    private func getTotalWorkoutsForPeriod() -> Int {
        let filteredSessions = getFilteredSessionsForPeriod()
        return filteredSessions.count
    }
    
    private func getTotalCaloriesForPeriod() -> Double {
        let filteredSessions = getFilteredSessionsForPeriod()
        return filteredSessions.reduce(0.0) { $0 + $1.caloriesBurned }
    }
    
    private func formattedTotalCalories() -> String {
        let calories = getTotalCaloriesForPeriod()
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: calories)) ?? "0"
    }

    private func getFilteredSessionsForPeriod() -> [WorkoutSession] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .day:
            let startOfDay = calendar.startOfDay(for: now)
            return sessions.filter { $0.date >= startOfDay }
            
        case .week:
            // Start week on Sunday
            var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            comps.weekday = 1 // Sunday
            guard let startOfWeek = calendar.date(from: comps) else {
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
        
        // Return all 24 hours but with selective labels (show every 4 hours)
        return (0..<24).map { hour in
            let reps = hourlyReps[hour] ?? 0
            // Only show labels for 0, 4, 8, 12, 16, 20
            let label = hour % 4 == 0 ? formatHourLabel(hour) : ""
            return BarData(label: label, value: reps)
        }
    }

    private func getColorForDay(date: Date, reps: Int, totalTargets: Int, sessionsCount: Int, useAccentColor: Bool = false) -> Color {
        let calendar = Calendar.current
        let profile = ProfileStore.load()
        let todayStart = calendar.startOfDay(for: Date())
        let dayStart = calendar.startOfDay(for: date)
        
        // Check if before onboarding
        if let onboardingDate = profile?.onboardingDate {
            let onboardingStart = calendar.startOfDay(for: onboardingDate)
            if dayStart < onboardingStart {
                return Color.gray.opacity(0.3)
            }
        }
        
        // Check if future date
        if dayStart > todayStart {
            return Color.gray.opacity(0.3)
        }
        
        // If no reps, show as missed (red) or gray
        if reps == 0 {
            return .red
        }
        
        // If using accent color mode (for weekly bars), just use accent color
        if useAccentColor {
            return themeManager.accentColor.color
        }
        
        // Otherwise, use status colors (for weekly rings)
        let targetReps: Int
        if totalTargets > 0 {
            targetReps = totalTargets
        } else {
            targetReps = max(1, plan?.targetReps ?? 20)
        }
        
        if Double(reps) >= Double(targetReps) {
            return .green // Complete
        } else {
            return .yellow // Partial
        }
    }
    
    private func getDailyData(for sessions: [WorkoutSession], showDayNames: Bool) -> [BarData] {
        let calendar = Calendar.current
        var dailyReps: [Date: Int] = [:]
        var dailyTargets: [Date: Int] = [:]
        var dailySessionCounts: [Date: Int] = [:]
        
        for session in sessions {
            let dayStart = calendar.startOfDay(for: session.date)
            dailyReps[dayStart, default: 0] += session.reps
            dailyTargets[dayStart, default: 0] += session.targetRepsAtStart ?? 0
            dailySessionCounts[dayStart, default: 0] += 1
        }
        
        if showDayNames {
            // Weekly: Show all 7 days of current week (starting Sunday)
            var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            comps.weekday = 1 // Sunday
            guard let startOfWeek = calendar.date(from: comps) else {
                return []
            }
            
            var result: [BarData] = []
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                    let reps = dailyReps[date] ?? 0
                    let targets = dailyTargets[date] ?? 0
                    let sessionCount = dailySessionCounts[date] ?? 0
                    // Use accent color for weekly bars
                    let color = getColorForDay(date: date, reps: reps, totalTargets: targets, sessionsCount: sessionCount, useAccentColor: true)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEEEE" // Single letter day name (S, M, T, W, T, F, S)
                    let label = formatter.string(from: date)
                    result.append(BarData(label: label, value: reps, color: color))
                }
            }
            return result
        } else {
            // Monthly: Show all days in the current month
            let now = Date()
            guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
                return []
            }
            
            // Get the actual number of days in the month
            let range = calendar.range(of: .day, in: .month, for: now)
            let totalDays = range?.count ?? 30
            
            // Show all days but only label every 5th day
            let daysToShow = Array(1...totalDays)
            
            var result: [BarData] = []
            for day in daysToShow {
                if day <= totalDays, let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                    let reps = dailyReps[date] ?? 0
                    // Only show labels for days 1, 5, 10, 15, 20, 25, 30
                    let label = (day == 1 || day % 5 == 0) ? "\(day)" : ""
                    result.append(BarData(label: label, value: reps))
                }
            }
            return result
        }
    }
    
    private func getMonthlyData(for sessions: [WorkoutSession]) -> [BarData] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        var monthlyReps: [Int: Int] = [:]
        
        for session in sessions {
            let sessionYear = calendar.component(.year, from: session.date)
            let sessionMonth = calendar.component(.month, from: session.date)
            
            // Only count sessions from current year
            if sessionYear == currentYear {
                monthlyReps[sessionMonth, default: 0] += session.reps
            }
        }
        
        let monthNames = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
        
        // Show all months up to current month
        return (1...currentMonth).map { month in
            BarData(label: monthNames[month - 1], value: monthlyReps[month] ?? 0)
        }
    }
    
    private func formatHourLabel(_ hour: Int) -> String {
        // Compact format for 24-hour display
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    private func getMaxValue(from data: [BarData]) -> Int {
        let maxValue = data.map { $0.value }.max() ?? 0
        // Round up to nearest nice number
        if maxValue == 0 { return 10 }
        if maxValue <= 5 { return 5 }
        if maxValue <= 10 { return 10 }
        
        // For values > 10, round up to next multiple of 10, 20, 50, or 100
        let magnitude = pow(10.0, floor(log10(Double(maxValue))))
        let normalized = Double(maxValue) / magnitude
        
        var roundedUp: Double
        if normalized <= 1.0 {
            roundedUp = 1.0
        } else if normalized <= 2.0 {
            roundedUp = 2.0
        } else if normalized <= 5.0 {
            roundedUp = 5.0
        } else {
            roundedUp = 10.0
        }
        
        return Int(ceil(roundedUp * magnitude))
    }
}

// MARK: - Supporting Views

struct BarData {
    let label: String
    let value: Int
    let color: Color?
    
    init(label: String, value: Int, color: Color? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }
}

struct BarGraphView: View {
    let data: [BarData]
    let maxValue: Int
    @EnvironmentObject var themeManager: ThemeManager
    
    private let chartHeight: CGFloat = 150
    private let xAxisHeight: CGFloat = 24
    private let yAxisWidth: CGFloat = 32
    private let gridLineCount: Int = 4
    
    var body: some View {
        VStack(spacing: 4) {
            // Main chart area: Y-axis + Chart
            HStack(alignment: .bottom, spacing: 4) {
                // Y-axis labels
                yAxisLabelsView
                    .frame(width: yAxisWidth)
                
                // Chart container
                chartContentView
            }
            .frame(height: chartHeight)
            .clipped()
            
            // X-axis labels
            xAxisLabelsView
                .frame(height: xAxisHeight)
        }
        .padding(12)
        .background(Color.gray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // Y-axis labels aligned with grid
    private var yAxisLabelsView: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(yAxisValues.reversed().enumerated()), id: \.offset) { index, value in
                Text("\(value)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
                
                if index < gridLineCount - 1 {
                    Spacer()
                }
            }
        }
        .frame(width: yAxisWidth, height: chartHeight)
    }
    
    // Chart content with grid and bars
    private var chartContentView: some View {
        GeometryReader { geometry in
            let chartWidth = geometry.size.width
            let barSpacing: CGFloat = 1
            let totalBars = CGFloat(data.count)
            let totalSpacing = barSpacing * max(0, totalBars - 1)
            let barWidth = totalBars > 0 ? max(2, (chartWidth - totalSpacing) / totalBars) : 2
            
            ZStack(alignment: .bottomLeading) {
                // Grid lines
                ForEach(0..<gridLineCount, id: \.self) { index in
                    let yPosition = CGFloat(index) * (chartHeight / CGFloat(gridLineCount - 1))
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 0.5)
                        .position(x: chartWidth / 2, y: yPosition)
                }
                
                // Bars
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                        let height = calculateBarHeight(for: item.value)
                        Rectangle()
                            .fill(item.color ?? themeManager.accentColor.color)
                            .frame(width: barWidth, height: height)
                            .cornerRadius(2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: chartWidth, height: chartHeight)
        }
    }
    
    // X-axis labels
    private var xAxisLabelsView: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: yAxisWidth + 4)
            
            HStack(spacing: 1) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    Text(item.label)
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
            }
            .padding(.leading, 8)
        }
    }
    
    // Calculate Y-axis values (always 4 values including zero)
    private var yAxisValues: [Int] {
        guard maxValue > 0 else {
            return [0, 5, 10, 15]
        }
        
        // Calculate step size for 3 intervals (4 values including zero)
        let steps = 3
        let stepSize = max(1, maxValue / steps)
        
        var values: [Int] = []
        for i in 0...steps {
            if i == steps {
                // Last value is exactly maxValue
                values.append(maxValue)
            } else {
                values.append(stepSize * i)
            }
        }
        
        return values
    }
    
    // Calculate bar height with safety bounds
    private func calculateBarHeight(for value: Int) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        
        let ratio = CGFloat(value) / CGFloat(maxValue)
        let height = ratio * chartHeight
        
        // Clamp height to valid range
        return min(max(0, height), chartHeight)
    }
}

struct WeeklyRingView: View {
    let plan: WorkoutPlan?
    let selectedDate: Date?
    @State private var refreshTrigger = UUID()
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        let weekDays = getWeekDays()
        let profile = ProfileStore.load()
        let accentColor = themeManager.accentColor.color
        
        HStack(spacing: 8) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 4) {
                    // Day label
                    Text(day.dayName)
                        .font(.caption2)
                        .foregroundStyle(day.isToday ? .white : .secondary)
                    
                    // Single color-coded ring
                    NavigationLink(destination: CalendarView(initialDate: day.date)) {
                        ZStack {
                            // Ring based on status (outer)
                            let ringColor = getRingColor(for: day, profile: profile)
                            let ringProgress = day.status == .missed ? 1.0 : day.repsRing
                            
                            if ringColor != Color.clear {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                                    .frame(width: 45, height: 45)
                                
                                Circle()
                                    .trim(from: 0, to: ringProgress)
                                    .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 45, height: 45)
                            }
                            
                            // Background circle with accent color (inner, smaller for spacing)
                            Circle()
                                .fill(day.isToday ? accentColor.opacity(0.4) : accentColor.opacity(0.15))
                                .frame(width: 37, height: 37)
                            
                            // Center text - theme aware
                            Text(day.repsText)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(colorScheme == .dark ? .white : .black)
                        }
                        .frame(width: 45, height: 45)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .id(refreshTrigger)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SessionsUpdated"))) { _ in
            refreshTrigger = UUID()
        }
    }
    
    private func getRingColor(for day: WeekDayData, profile: UserProfile?) -> Color {
        // Check if before onboarding
        let calendar = Calendar.current
        if let onboardingDate = profile?.onboardingDate {
            let onboardingStart = calendar.startOfDay(for: onboardingDate)
            if day.date < onboardingStart {
                return .clear
            }
        }
        
        // Check if future date
        let today = calendar.startOfDay(for: Date())
        if day.date > today {
            return .clear
        }
        
        switch day.status {
        case .missed:
            return .red
        case .partial:
            return .yellow
        case .complete:
            return .green
        case .none:
            return .clear
        }
    }

    private func getWeekDays() -> [WeekDayData] {
        let calendar = Calendar.current
        let now = Date()
        let sessions = SessionStore.load()
        let profile = ProfileStore.load()

        // Start week on Sunday
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 1 // Sunday
        guard let weekStart = calendar.date(from: comps) else { return createEmptyWeek() }

        let weekDayNames = ["S", "M", "T", "W", "T", "F", "S"] // Sunday to Saturday
        var result: [WeekDayData] = []
        
        let todayStart = calendar.startOfDay(for: now)
        
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
            
            // Calculate total reps and total targets for all sessions
            let dayReps = daySessions.reduce(0) { $0 + $1.reps }
            let totalTargets = daySessions.reduce(0) { $0 + ($1.targetRepsAtStart ?? 0) }
            
            // Determine target: use sum of captured targets if available, otherwise use plan
            let targetReps: Int
            if totalTargets > 0 {
                targetReps = totalTargets
            } else {
                // Fall back to plan's day target or global plan target
                let planDayTarget = plan?.days.first(where: { calendar.isDate($0.completedDate ?? dayDate, inSameDayAs: dayDate) })?.targetReps
                let fallbackPlanTarget = plan?.targetReps
                targetReps = max(1, planDayTarget ?? fallbackPlanTarget ?? 20)
            }
            
            // Ring 1: Reps progress (only fill if goal is actually met)
            let ring1 = min(1.0, Double(dayReps) / Double(targetReps))
            
            // Ring 2: Workout completion (only if there's a workout)
            let ring2 = daySessions.count > 0 ? 1.0 : 0.0
            
            // Ring 3: Extra achievement (2x target)
            let ring3 = min(1.0, Double(dayReps) / Double(targetReps * 2))
            
            // Display total reps in center
            let repsText = dayReps > 0 ? "\(dayReps)" : ""
            
            // Determine status based on day context
            let status: DayStatus
            
            // Check if before onboarding
            if let onboardingDate = profile?.onboardingDate {
                let onboardingStart = calendar.startOfDay(for: onboardingDate)
                if dayStart < onboardingStart {
                    status = .none
                } else if dayStart > todayStart {
                    // Future date
                    status = .none
                } else {
                    // Past or today
                    if dayReps == 0 {
                        status = .missed
                    } else if ring1 >= 1.0 {
                        status = .complete
                    } else {
                        status = .partial(progress: ring1)
                    }
                }
            } else {
                // No onboarding date, check if future
                if dayStart > todayStart {
                    status = .none
                } else {
                    if dayReps == 0 {
                        status = .missed
                    } else if ring1 >= 1.0 {
                        status = .complete
                    } else {
                        status = .partial(progress: ring1)
                    }
                }
            }
            
            result.append(WeekDayData(
                dayName: weekDayNames[i],
                isToday: isToday,
                date: dayDate,
                repsRing: ring1,
                completionRing: ring2,
                extraRing: ring3,
                repsText: repsText,
                status: status
            ))
        }
        
        return result.isEmpty ? createEmptyWeek() : result
    }
    
    private func createEmptyWeek() -> [WeekDayData] {
        let calendar = Calendar.current
        let now = Date()
        let weekDayNames = ["S", "M", "T", "W", "T", "F", "S"] // Sunday to Saturday
        let currentDayOfWeek = calendar.component(.weekday, from: now) - 1 // 0 = Sunday
        
        return (0..<7).map { i in
            let dayName = weekDayNames[i]
            let isToday = i == currentDayOfWeek
            return WeekDayData(dayName: dayName, isToday: isToday, date: now, repsRing: 0.0, completionRing: 0.0, extraRing: 0.0, repsText: "", status: .none)
        }
    }
}

struct WeekDayData {
    let dayName: String
    let isToday: Bool
    let date: Date
    let repsRing: Double
    let completionRing: Double
    let extraRing: Double
    let repsText: String
    let status: DayStatus
}

struct WeeklyCaloriesChart: View {
    let sessions: [WorkoutSession]
    @EnvironmentObject var themeManager: ThemeManager
    
    private let chartHeight: CGFloat = 100
    
    var body: some View {
        let weekData = getWeeklyCaloriesData()
        let maxCalories = weekData.map { $0.calories }.max() ?? 100
        
        VStack(spacing: 8) {
            // Line chart
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = chartHeight
                
                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    ForEach(0..<3, id: \.self) { index in
                        let yPosition = CGFloat(index) * (height / 2)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 0.5)
                            .position(x: width / 2, y: yPosition)
                    }
                    
                    // Line path
                    Path { path in
                        // Divide width into 7 equal columns (one for each day)
                        let columnWidth = width / 7.0
                        
                        for (index, data) in weekData.enumerated() {
                            // Center point within each column
                            let x = (CGFloat(index) * columnWidth) + (columnWidth / 2.0)
                            let normalizedValue = maxCalories > 0 ? CGFloat(data.calories) / CGFloat(maxCalories) : 0
                            let y = height - (normalizedValue * height)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(themeManager.accentColor.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    
                    // Data points
                    ForEach(Array(weekData.enumerated()), id: \.offset) { index, data in
                        // Divide width into 7 equal columns (one for each day)
                        let columnWidth = width / 7.0
                        // Center point within each column
                        let x = (CGFloat(index) * columnWidth) + (columnWidth / 2.0)
                        let normalizedValue = maxCalories > 0 ? CGFloat(data.calories) / CGFloat(maxCalories) : 0
                        let y = height - (normalizedValue * height)
                        
                        Circle()
                            .fill(themeManager.accentColor.color)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }
                }
                .frame(height: height)
            }
            .frame(height: chartHeight)
            
            // Day labels
            HStack(spacing: 0) {
                ForEach(Array(weekData.enumerated()), id: \.offset) { _, data in
                    VStack(spacing: 4) {
                        Text(data.dayName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("\(Int(data.calories))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(themeManager.accentColor.color)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func getWeeklyCaloriesData() -> [CaloriesData] {
        let calendar = Calendar.current
        let now = Date()
        
        // Start week on Sunday (same logic as WeeklyRingView)
        var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 1 // Sunday = 1
        guard let startOfWeek = calendar.date(from: comps) else { return [] }
        
        let weekDayNames = ["S", "M", "T", "W", "T", "F", "S"]
        var result: [CaloriesData] = []
        
        // Always return exactly 7 days
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) else { continue }
            
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            
            let daySessions = sessions.filter { $0.date >= dayStart && $0.date < dayEnd }
            let totalCalories = daySessions.reduce(0.0) { $0 + $1.caloriesBurned }
            
            result.append(CaloriesData(dayName: weekDayNames[i], calories: totalCalories))
        }
        
        // Ensure we always return exactly 7 days
        return Array(result.prefix(7))
    }
}

struct CaloriesData {
    let dayName: String
    let calories: Double
}
