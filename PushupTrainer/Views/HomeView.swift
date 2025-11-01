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
                        let maxVal = getMaxValue(from: barData)
                        if !barData.isEmpty {
                            BarGraphView(data: barData, maxValue: maxVal)
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
            .defaultScrollAnchor(.top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { Text("").font(.headline) } }
            .background(
                Group {
                    if shouldUseLightTheme {
                        LinearGradient(gradient: Gradient(colors: [Color.white, Color(white: 0.95)]), startPoint: .top, endPoint: .bottom)
                    } else {
                        LinearGradient(gradient: Gradient(colors: [Color(red:0.05, green:0.08, blue:0.18), Color(red:0.18, green:0.06, blue:0.20)]), startPoint: .top, endPoint: .bottom)
                    }
                }
                .ignoresSafeArea()
                .id(themeManager.theme)
            )
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
        
        // Return all 24 hours but with selective labels (show every 4 hours)
        return (0..<24).map { hour in
            let reps = hourlyReps[hour] ?? 0
            // Only show labels for 0, 4, 8, 12, 16, 20
            let label = hour % 4 == 0 ? formatHourLabel(hour) : ""
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
        
        if showDayNames {
            // Weekly: Show all 7 days of current week
            guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
                return []
            }
            
            var result: [BarData] = []
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) {
                    let reps = dailyReps[date] ?? 0
                    let formatter = DateFormatter()
                    formatter.dateFormat = "E" // Single letter day name
                    let label = formatter.string(from: date)
                    result.append(BarData(label: label, value: reps))
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
}

struct BarGraphView: View {
    let data: [BarData]
    let maxValue: Int
    
    private let chartHeight: CGFloat = 150
    private let xAxisHeight: CGFloat = 24
    private let yAxisWidth: CGFloat = 32
    private let gridLineCount: Int = 6
    
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
    }
    
    // Y-axis labels aligned with grid
    private var yAxisLabelsView: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(yAxisValues.reversed().enumerated()), id: \.offset) { index, value in
                Text("\(value)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(height: index == 0 || index == gridLineCount - 1 ? nil : chartHeight / CGFloat(gridLineCount - 1), alignment: .center)
                    .padding(.trailing, 4)
                
                if index < gridLineCount - 1 {
                    Spacer(minLength: 0)
                        .frame(height: chartHeight / CGFloat(gridLineCount - 1))
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
                            .fill(Color.purple)
                            .frame(width: barWidth, height: height)
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
    
    // Calculate Y-axis values
    private var yAxisValues: [Int] {
        var values: [Int] = []
        let steps = gridLineCount - 1
        
        guard maxValue > 0 else {
            return [0, 1, 2, 3, 4, 5]
        }
        
        let stepSize = max(1, maxValue / steps)
        
        for i in 0..<gridLineCount {
            values.append(min(stepSize * i, maxValue))
        }
        
        // Ensure the last value is exactly maxValue
        values[gridLineCount - 1] = maxValue
        
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
    
    var body: some View {
        let weekDays = getWeekDays()
        let profile = ProfileStore.load()
        
        HStack(spacing: 8) {
            ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 4) {
                    // Day label
                    Text(day.dayName)
                        .font(.caption2)
                        .foregroundStyle(day.isToday ? .white : .secondary)
                    
                    // Single color-coded ring
                    NavigationLink(destination: CalendarView()) {
                        ZStack {
                            // Ring based on status
                            let ringColor = getRingColor(for: day, profile: profile)
                            let ringProgress = day.status == .missed ? 1.0 : day.repsRing
                            
                            if ringColor != Color.clear {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                                
                                Circle()
                                    .trim(from: 0, to: ringProgress)
                                    .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        .frame(width: 45, height: 45)
                        .overlay(
                            Circle()
                                .strokeBorder(day.isToday ? Color.white : Color.clear, lineWidth: 1.5)
                                .background(
                                    Circle()
                                        .fill(day.isToday ? Color.accentColor.opacity(0.3) : Color.clear)
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
            
            // Determine status
            let status: DayStatus
            if dayReps == 0 {
                status = .missed
            } else if ring1 >= 1.0 {
                status = .complete
            } else {
                status = .partial(progress: ring1)
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
        let weekDayNames = ["M", "T", "W", "T", "F", "S", "S"]
        let currentDayOfWeek = calendar.component(.weekday, from: now) - 1
        let adjustedDayOfWeek = (currentDayOfWeek + 6) % 7 // Convert to Monday-based week
        
        return (0..<7).map { i in
            let dayName = weekDayNames[i]
            let isToday = i == adjustedDayOfWeek
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
