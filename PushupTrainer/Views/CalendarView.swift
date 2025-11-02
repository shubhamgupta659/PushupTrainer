//
//  CalendarView.swift
//  PushupTrainer
//

import SwiftUI

struct CalendarView: View {
    let initialDate: Date?
    
    @State private var sessions: [WorkoutSession] = SessionStore.load()
    @State private var plan: WorkoutPlan? = PlanStore.load()
    @State private var profile: UserProfile? = ProfileStore.load()
    @State private var selectedDate: Date = Date()
    @State private var showDetailView: Bool = false
    
    init(initialDate: Date? = nil) {
        self.initialDate = initialDate
    }
    
    private let calendar = Calendar.current
    private var today: Date { Date() }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Infinite calendar months
                    ForEach(visibleMonths, id: \.self) { month in
                        MonthCalendarView(
                            month: month,
                            sessions: sessions,
                            plan: plan,
                            profile: profile,
                            selectedDate: selectedDate,
                            onDateTap: { date in
                                selectedDate = date
                                showDetailView = true
                            }
                        )
                        .padding(.bottom, 30)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Activity")
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
                // If initial date is provided, select it and show detail view
                if let initialDate = initialDate {
                    selectedDate = initialDate
                    showDetailView = true
                }
                
                sessions = SessionStore.load()
                plan = PlanStore.load()
                profile = ProfileStore.load()
                // Listen for session updates
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("SessionsUpdated"),
                    object: nil,
                    queue: .main
                ) { _ in
                    sessions = SessionStore.load()
                    plan = PlanStore.load()
                    profile = ProfileStore.load()
                }
            }
            .sheet(isPresented: $showDetailView) {
                DayDetailView(date: selectedDate, sessions: sessionsForDate(selectedDate)) {
                    sessions = SessionStore.load()
                    plan = PlanStore.load()
                    showDetailView = false
                }
            }
        }
    }
    
    // Generate visible months based on data range
    private var visibleMonths: [Date] {
        var months: [Date] = []
        let now = Date()
        
        // Find earliest session date or use onboarding date
        var startDate: Date?
        if let earliestSession = sessions.min(by: { $0.date < $1.date }) {
            startDate = earliestSession.date
        }
        if let onboardingDate = profile?.onboardingDate {
            if let earliest = startDate {
                startDate = min(earliest, onboardingDate)
            } else {
                startDate = onboardingDate
            }
        }
        
        // Default to 3 months ago if no data
        let effectiveStartDate = startDate ?? calendar.date(byAdding: .month, value: -3, to: now) ?? now
        
        // Generate months from start to next month
        guard let startOfStartMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: effectiveStartDate)),
              let endOfNextMonth = calendar.date(byAdding: .month, value: 2, to: now) else {
            return [now]
        }
        
        var currentMonth = startOfStartMonth
        while currentMonth <= endOfNextMonth {
            months.append(currentMonth)
            guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { break }
            currentMonth = next
        }
        
        return months.isEmpty ? [now] : months
    }
    
    private func sessionsForDate(_ date: Date) -> [WorkoutSession] {
        sessions.filter { session in
            calendar.isDate(session.date, inSameDayAs: date)
        }
    }
}

struct MonthCalendarView: View {
    let month: Date
    let sessions: [WorkoutSession]
    let plan: WorkoutPlan?
    let profile: UserProfile?
    let selectedDate: Date
    let onDateTap: (Date) -> Void
    
    private let calendar = Calendar.current
    private let dateFormatter = DateFormatter()
    
    var body: some View {
        VStack(spacing: 12) {
            // Month header
            Text(monthTitle)
                .font(.title2.bold())
                .padding(.horizontal)
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(monthDays, id: \.self) { date in
                    if let date = date {
                        let status = statusForDate(date)
                        CalendarDayView(
                            date: date,
                            isToday: calendar.isDateInToday(date),
                            status: status,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                        )
                        .onTapGesture {
                            onDateTap(date)
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var monthTitle: String {
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: month)
    }
    
    private var monthDays: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingSpaces = (firstWeekday - 1) % 7
        
        var days: [Date?] = Array(repeating: nil, count: leadingSpaces)
        
        var currentDay: Date? = monthStart
        while let day = currentDay, day <= monthEnd {
            days.append(day)
            currentDay = calendar.date(byAdding: .day, value: 1, to: day)
        }
        
        return days
    }
    
    private func statusForDate(_ date: Date) -> DayStatus {
        // Get all sessions for this day
        let daySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
        
        // Calculate total reps and total targets for all sessions
        let totalReps = daySessions.reduce(0) { $0 + $1.reps }
        let totalTargets = daySessions.reduce(0) { $0 + ($1.targetRepsAtStart ?? 0) }
        
        // Check if date is before onboarding
        if let onboardingDate = profile?.onboardingDate {
            let onboardingStart = calendar.startOfDay(for: onboardingDate)
            let dayStart = calendar.startOfDay(for: date)
            if dayStart < onboardingStart {
                return .none // Don't show any status for days before onboarding
            }
        }
        
        // Check if it's a future date
        let today = calendar.startOfDay(for: Date())
        let dayStart = calendar.startOfDay(for: date)
        if dayStart > today {
            return .none // Don't show status for future dates
        }
        
        // No activity - check if day has passed
        if totalReps == 0 {
            return .missed // Red for missed days
        }
        
        // Has activity - calculate progress
        // If sessions have captured targets, use those; otherwise fall back to plan
        let targetReps: Int
        if totalTargets > 0 {
            targetReps = totalTargets
        } else if let plan = plan {
            // Find the target reps for this date from plan
            let planStart = calendar.startOfDay(for: plan.startDate)
            guard let daysDiff = calendar.dateComponents([.day], from: planStart, to: dayStart).day else {
                return .complete // Can't calculate, assume complete
            }
            let dayNumber = daysDiff + 1
            
            // Find matching plan day
            if let planDay = plan.days.first(where: { $0.dayNumber == dayNumber }) {
                targetReps = planDay.targetReps
            } else {
                targetReps = plan.targetReps
            }
        } else {
            // No plan and no captured targets, just show complete
            return .complete
        }
        
        let progress = min(Double(totalReps) / Double(targetReps), 1.0)
        
        if progress >= 1.0 {
            return .complete // Green for complete
        } else {
            return .partial(progress: progress) // Yellow for partial
        }
    }
}

enum DayStatus {
    case none // No ring
    case missed // Red ring for missed workout
    case partial(progress: Double) // Yellow ring for below target
    case complete // Green ring for met/exceeded target
}

struct CalendarDayView: View {
    let date: Date
    let isToday: Bool
    let status: DayStatus
    let isSelected: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    private let calendar = Calendar.current
    
    var body: some View {
        let accentColor = themeManager.accentColor.color
        
        ZStack {
            // Progress ring based on status
            switch status {
            case .none:
                EmptyView()
                
            case .missed:
                // Red ring for missed workout
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: 44, height: 44)
                
            case .partial(let progress):
                // Yellow ring for below target
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.yellow,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                
            case .complete:
                // Green ring for complete
                Circle()
                    .stroke(Color.green, lineWidth: 3)
                    .frame(width: 44, height: 44)
            }
            
            // Background circle for selected/today
            if isSelected {
                Circle()
                    .fill(accentColor)
                    .frame(width: 36, height: 36)
            } else if isToday && status == .none {
                Circle()
                    .stroke(accentColor, lineWidth: 2)
                    .frame(width: 36, height: 36)
            }
            
            // Day number
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday || isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : (isToday ? accentColor : .primary))
        }
        .frame(width: 48, height: 48)
    }
}

extension DayStatus: Equatable {
    static func == (lhs: DayStatus, rhs: DayStatus) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none), (.missed, .missed), (.complete, .complete):
            return true
        case (.partial(let lp), .partial(let rp)):
            return lp == rp
        default:
            return false
        }
    }
}

struct DayDetailView: View {
    let date: Date
    let sessions: [WorkoutSession]
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date header
                    Text(dateFormatter.string(from: date))
                        .font(.title2.bold())
                        .padding(.top)
                    
                    if sessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                            Text("No workouts on this day")
                                .font(.headline)
                            Text("Start a workout to see your activity here")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Activities
                        ForEach(sessions) { session in
                            ActivityCard(session: session)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Activity Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

struct ActivityCard: View {
    let session: WorkoutSession
    @State private var showDeleteConfirm: Bool = false
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(timeFormatter.string(from: session.startTime))
                    .font(.headline)
                Spacer()
                Menu {
                    Button(role: .destructive, action: {
                        showDeleteConfirm = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    if let target = session.targetRepsAtStart {
                        Text("\(session.reps) / \(target) reps")
                            .font(.title3.bold())
                    } else {
                        Text("\(session.reps) reps")
                            .font(.title3.bold())
                    }
                    
                    Text("\(session.durationSeconds/60)m \(session.durationSeconds%60)s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("Mode: \(session.mode.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(Int(session.caloriesBurned)) kcal")
                        .font(.headline)
                    
                    if let avg = session.averageHeartRateBPM, let max = session.maxHeartRateBPM {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(avg))/\(Int(max)) bpm")
                                .font(.caption)
                            Text("avg/max")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let rec = session.recoveryHeartRateDropBPM {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(rec)) bpm")
                                .font(.caption)
                            Text("recovery (60s)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .alert("Delete Activity?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func deleteSession() {
        var all = SessionStore.load()
        all.removeAll { $0.id == session.id }
        SessionStore.save(all)
        NotificationCenter.default.post(name: NSNotification.Name("SessionsUpdated"), object: nil)
    }
}
