//
//  PushupTrainerWidget.swift
//  PushupTrainerWidget
//

import WidgetKit
import SwiftUI
import Charts

// MARK: - Widget Entry
struct WorkoutEntry: TimelineEntry {
    let date: Date
    let weekSummary: WeekSummary
    let recentSessions: [WorkoutSession]
    let accentColor: Color
}

// MARK: - Week Summary Model
struct WeekSummary: Codable {
    let totalReps: Int
    let totalSessions: Int
    let averageReps: Int
    let currentStreak: Int
    let totalCalories: Int
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(
            date: Date(),
            weekSummary: WeekSummary(totalReps: 350, totalSessions: 7, averageReps: 50, currentStreak: 7, totalCalories: 175),
            recentSessions: generatePlaceholderSessions(),
            accentColor: loadAccentColor()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> ()) {
        let entry = WorkoutEntry(
            date: Date(),
            weekSummary: loadWeekSummary(),
            recentSessions: loadRecentSessions(),
            accentColor: loadAccentColor()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = WorkoutEntry(
            date: currentDate,
            weekSummary: loadWeekSummary(),
            recentSessions: loadRecentSessions(),
            accentColor: loadAccentColor()
        )
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // MARK: - Load Accent Color
    private func loadAccentColor() -> Color {
        // Load from App Group (shared with main app)
        let appGroupID = "group.com.coder.ai.PushupTrainer"
        let accentRaw: String?
        
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            accentRaw = sharedDefaults.string(forKey: "accentColor")
        } else {
            accentRaw = nil
        }
        
        #if DEBUG
        print("[Widget] 🎨 Loading accent color from App Group: \(accentRaw ?? "nil")")
        #endif
        
        // Map string to Color
        switch accentRaw {
        case "Purple": return .purple
        case "Blue": return .blue
        case "Green": return .green
        case "Orange": return .orange
        case "Pink": return .pink
        case "Red": return .red
        case "Teal": return .teal
        case "Indigo": return .indigo
        default: 
            #if DEBUG
            print("[Widget] ⚠️ No accent color found, using default blue")
            #endif
            return .blue // Default fallback
        }
    }
    
    // MARK: - Data Loading
    private func loadWeekSummary() -> WeekSummary {
        let sessions = loadRecentSessions()
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday = 1
        
        // Get start of current week (Sunday)
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        // Get end of current week (Saturday)
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        let weekSessions = sessions.filter { $0.date >= startOfWeek && $0.date <= endOfWeek }
        let totalReps = weekSessions.reduce(0) { $0 + $1.reps }
        let averageReps = weekSessions.isEmpty ? 0 : totalReps / weekSessions.count
        let totalCalories = Int(weekSessions.reduce(0.0) { $0 + $1.caloriesBurned })
        
        // Calculate streak
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        while true {
            let hasWorkout = sessions.contains { calendar.isDate($0.date, inSameDayAs: checkDate) }
            if hasWorkout {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }
        
        return WeekSummary(
            totalReps: totalReps,
            totalSessions: weekSessions.count,
            averageReps: averageReps,
            currentStreak: streak,
            totalCalories: totalCalories
        )
    }
    
    private func loadRecentSessions() -> [WorkoutSession] {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.coder.ai.PushupTrainer") else {
            #if DEBUG
            print("[Widget] ❌ Failed to access App Group")
            #endif
            return []
        }
        
        guard let data = sharedDefaults.data(forKey: "workoutSessions") else {
            #if DEBUG
            print("[Widget] ⚠️ No data found in App Group for key 'workoutSessions'")
            #endif
            return []
        }
        
        guard let sessions = try? JSONDecoder().decode([WorkoutSession].self, from: data) else {
            #if DEBUG
            print("[Widget] ❌ Failed to decode sessions")
            #endif
            return []
        }
        
        #if DEBUG
        print("[Widget] ✅ Loaded \(sessions.count) total sessions from App Group")
        #endif
        
        // Return sessions from current week (Sunday to Saturday)
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday = 1
        
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        let recentSessions = sessions.filter { $0.date >= startOfWeek && $0.date <= endOfWeek }.sorted { $0.date < $1.date }
        
        #if DEBUG
        print("[Widget] ✅ Found \(recentSessions.count) sessions from current week (Sunday-Saturday)")
        #endif
        
        return recentSessions
    }
    
    private func generatePlaceholderSessions() -> [WorkoutSession] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday = 1
        
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        var sessions: [WorkoutSession] = []
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: i, to: startOfWeek)!
            sessions.append(WorkoutSession(
                id: UUID(),
                date: date,
                startTime: date,
                endTime: date.addingTimeInterval(300),
                reps: Int.random(in: 30...70),
                durationSeconds: 300,
                mode: .manual,
                caloriesBurned: 25,
                notes: "",
                repsTimestamps: [],
                targetRepsAtStart: 50,
                averageHeartRateBPM: nil,
                maxHeartRateBPM: nil,
                recoveryHeartRateDropBPM: nil
            ))
        }
        return sessions
    }
}

// MARK: - Medium Widget (This Week Summary)
struct MediumWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(entry.accentColor)
                Text("This Week")
                    .font(.headline)
                    .foregroundStyle(colorScheme == .dark ? .white : Color(white: 0.15))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
                .overlay(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
            
            Spacer()
            
            // Stats Grid - Centered
            HStack(spacing: 0) {
                StatCard(
                    value: "\(entry.weekSummary.totalReps)",
                    label: "Total Reps",
                    icon: "number.circle.fill",
                    color: entry.accentColor,
                    colorScheme: colorScheme
                )
                
                StatCard(
                    value: "\(entry.weekSummary.totalSessions)",
                    label: "Workouts",
                    icon: "flame.fill",
                    color: entry.accentColor,
                    colorScheme: colorScheme
                )
                
                StatCard(
                    value: "\(entry.weekSummary.totalCalories)",
                    label: "Calories",
                    icon: "bolt.fill",
                    color: entry.accentColor,
                    colorScheme: colorScheme
                )
                
                StatCard(
                    value: "\(entry.weekSummary.currentStreak)",
                    label: "Day Streak",
                    icon: "calendar.badge.checkmark",
                    color: .green,
                    colorScheme: colorScheme
                )
            }
            
            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            ZStack {
                Color(uiColor: .systemBackground)
                LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .widgetURL(URL(string: "pushuptrainer://home"))
    }
}

// MARK: - Large Widget (Bar Chart)
struct LargeWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity Overview")
                        .font(.headline)
                        .foregroundStyle(colorScheme == .dark ? .white : Color(white: 0.15))
                    Text("Last 7 Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.weekSummary.totalReps)")
                        .font(.title.bold())
                        .foregroundStyle(entry.accentColor)
                    Text("total reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer(minLength: 4)
            
            // Bar Chart
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(getLast7Days(), id: \.self) { day in
                        let reps = getRepsForDay(day)
                        BarMark(
                            x: .value("Day", dayName(day)),
                            y: .value("Reps", reps)
                        )
                        .foregroundStyle(
                            reps > 0 ? entry.accentColor.gradient : (colorScheme == .dark ? Color.gray.opacity(0.3).gradient : Color.gray.opacity(0.2).gradient)
                        )
                        .cornerRadius(4)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                // Fallback for older iOS versions
                SimplifiedBarChart(entry: entry, colorScheme: colorScheme)
            }
            
            Spacer(minLength: 4)
            
            // Quick Stats
            HStack(spacing: 8) {
                QuickStat(icon: "flame.fill", value: "\(entry.weekSummary.totalSessions)", label: "Workouts", color: entry.accentColor, colorScheme: colorScheme)
                QuickStat(icon: "chart.line.uptrend.xyaxis", value: "\(entry.weekSummary.averageReps)", label: "Avg Reps", color: entry.accentColor, colorScheme: colorScheme)
                QuickStat(icon: "calendar.badge.checkmark", value: "\(entry.weekSummary.currentStreak)", label: "Streak", color: .green, colorScheme: colorScheme)
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            ZStack {
                Color(uiColor: .systemBackground)
                LinearGradient(
                    colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .widgetURL(URL(string: "pushuptrainer://activity"))
    }
    
    private func getLast7Days() -> [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday = 1
        
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        return (0..<7).map { days in
            calendar.date(byAdding: .day, value: days, to: startOfWeek)!
        }
    }
    
    private func getRepsForDay(_ day: Date) -> Int {
        let calendar = Calendar.current
        return entry.recentSessions
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.reps }
    }
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(colorScheme == .dark ? .white : Color(white: 0.15))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(colorScheme == .dark ? .white : Color(white: 0.15))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SimplifiedBarChart: View {
    var entry: Provider.Entry
    var colorScheme: ColorScheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(getLast7Days(), id: \.self) { day in
                VStack(spacing: 4) {
                    let reps = getRepsForDay(day)
                    let maxReps = getMaxReps()
                    let height = maxReps > 0 ? CGFloat(reps) / CGFloat(maxReps) * 100 : 0
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(reps > 0 ? entry.accentColor : (colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)))
                        .frame(height: max(4, height))
                    
                    Text(dayName(day))
                        .font(.caption2)
                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 120)
    }
    
    private func getLast7Days() -> [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday = 1
        
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        return (0..<7).map { days in
            calendar.date(byAdding: .day, value: days, to: startOfWeek)!
        }
    }
    
    private func getRepsForDay(_ day: Date) -> Int {
        let calendar = Calendar.current
        return entry.recentSessions
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.reps }
    }
    
    private func getMaxReps() -> Int {
        getLast7Days().map { getRepsForDay($0) }.max() ?? 1
    }
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Widget Configuration
struct MediumWorkoutWidget: Widget {
    let kind: String = "MediumWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("This Week")
        .description("View your workout summary for this week.")
        .supportedFamilies([.systemMedium])
    }
}

struct LargeWorkoutWidget: Widget {
    let kind: String = "LargeWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Activity Overview")
        .description("View your workout activity with a bar chart.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Widget Bundle
@main
struct PushupTrainerWidgetBundle: WidgetBundle {
    var body: some Widget {
        MediumWorkoutWidget()
        LargeWorkoutWidget()
    }
}

