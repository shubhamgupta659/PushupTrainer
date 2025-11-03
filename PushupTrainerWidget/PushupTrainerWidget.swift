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
}

// MARK: - Week Summary Model
struct WeekSummary: Codable {
    let totalReps: Int
    let totalSessions: Int
    let averageReps: Int
    let currentStreak: Int
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(
            date: Date(),
            weekSummary: WeekSummary(totalReps: 350, totalSessions: 7, averageReps: 50, currentStreak: 7),
            recentSessions: generatePlaceholderSessions()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> ()) {
        let entry = WorkoutEntry(
            date: Date(),
            weekSummary: loadWeekSummary(),
            recentSessions: loadRecentSessions()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = WorkoutEntry(
            date: currentDate,
            weekSummary: loadWeekSummary(),
            recentSessions: loadRecentSessions()
        )
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // MARK: - Data Loading
    private func loadWeekSummary() -> WeekSummary {
        let sessions = loadRecentSessions()
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        let weekSessions = sessions.filter { $0.date >= weekAgo }
        let totalReps = weekSessions.reduce(0) { $0 + $1.reps }
        let averageReps = weekSessions.isEmpty ? 0 : totalReps / weekSessions.count
        
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
            currentStreak: streak
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
        
        // Return last 7 days of sessions
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let recentSessions = sessions.filter { $0.date >= weekAgo }.sorted { $0.date < $1.date }
        
        #if DEBUG
        print("[Widget] ✅ Found \(recentSessions.count) sessions from last 7 days")
        #endif
        
        return recentSessions
    }
    
    private func generatePlaceholderSessions() -> [WorkoutSession] {
        let calendar = Calendar.current
        var sessions: [WorkoutSession] = []
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
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
        return sessions.reversed()
    }
}

// MARK: - Medium Widget (This Week Summary)
struct MediumWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("This Week")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Stats Grid
            HStack(spacing: 16) {
                StatCard(
                    value: "\(entry.weekSummary.totalReps)",
                    label: "Total Reps",
                    icon: "number.circle.fill",
                    color: .blue
                )
                
                StatCard(
                    value: "\(entry.weekSummary.totalSessions)",
                    label: "Workouts",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatCard(
                    value: "\(entry.weekSummary.currentStreak)",
                    label: "Day Streak",
                    icon: "calendar.badge.checkmark",
                    color: .green
                )
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            ZStack {
                (colorScheme == .dark ? Color.black : Color.white)
                LinearGradient(
                    colors: [Color.orange.opacity(0.15), Color.purple.opacity(0.15)],
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
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity Overview")
                        .font(.headline)
                    Text("Last 7 Days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(entry.weekSummary.totalReps)")
                        .font(.title.bold())
                        .foregroundStyle(.orange)
                    Text("total reps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
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
                            reps > 0 ? Color.orange.gradient : Color.gray.opacity(0.3).gradient
                        )
                        .cornerRadius(4)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: 120)
            } else {
                // Fallback for older iOS versions
                SimplifiedBarChart(entry: entry)
            }
            
            // Quick Stats
            HStack(spacing: 12) {
                QuickStat(icon: "flame.fill", value: "\(entry.weekSummary.totalSessions)", label: "Workouts", color: .orange)
                QuickStat(icon: "chart.line.uptrend.xyaxis", value: "\(entry.weekSummary.averageReps)", label: "Avg Reps", color: .blue)
                QuickStat(icon: "calendar.badge.checkmark", value: "\(entry.weekSummary.currentStreak)", label: "Streak", color: .green)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            ZStack {
                (colorScheme == .dark ? Color.black : Color.white)
                LinearGradient(
                    colors: [Color.orange.opacity(0.15), Color.purple.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .widgetURL(URL(string: "pushuptrainer://activity"))
    }
    
    private func getLast7Days() -> [Date] {
        let calendar = Calendar.current
        return (0..<7).map { days in
            calendar.date(byAdding: .day, value: -days, to: Date())!
        }.reversed()
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

struct QuickStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SimplifiedBarChart: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(getLast7Days(), id: \.self) { day in
                VStack(spacing: 4) {
                    let reps = getRepsForDay(day)
                    let maxReps = getMaxReps()
                    let height = maxReps > 0 ? CGFloat(reps) / CGFloat(maxReps) * 100 : 0
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(reps > 0 ? Color.orange : Color.gray.opacity(0.3))
                        .frame(height: max(4, height))
                    
                    Text(dayName(day))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 120)
    }
    
    private func getLast7Days() -> [Date] {
        let calendar = Calendar.current
        return (0..<7).map { days in
            calendar.date(byAdding: .day, value: -days, to: Date())!
        }.reversed()
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

