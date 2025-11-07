//
//  CalendarView.swift
//  PushupTrainer
//

import SwiftUI
import WidgetKit

struct CalendarView: View {
    let initialDate: Date?
    
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("premiumUnlocked") private var premiumUnlocked: Bool = false
    @State private var sessions: [WorkoutSession] = SessionStore.load()
    @State private var plan: WorkoutPlan? = PlanStore.load()
    @State private var profile: UserProfile? = ProfileStore.load()
    @State private var selectedDate: Date = Date()
    @State private var showDetailView: Bool = false
    @State private var showManualLogSheet: Bool = false
    @State private var manualLogInitialDate: Date = Date()
    @State private var manualLogDefaultTarget: Int? = nil
    
    init(initialDate: Date? = nil) {
        self.initialDate = initialDate
    }
    
    private let calendar = Calendar.current
    private var today: Date { Date() }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
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
                            .id(month) // Add ID for scrolling
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
                    
                    // Scroll to current month
                    if let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                proxy.scrollTo(currentMonthStart, anchor: .top)
                            }
                        }
                    }
                    
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
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: {
                    manualLogInitialDate = clampManualLogDate(selectedDate)
                    manualLogDefaultTarget = planTarget(for: manualLogInitialDate)
                    showManualLogSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(themeManager.accentColor.color, Color(uiColor: .systemBackground))
                        .shadow(color: themeManager.accentColor.color.opacity(0.4), radius: 8, x: 0, y: 6)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 32)
                .accessibilityLabel("Log workout manually")
            }
            .sheet(isPresented: $showDetailView) {
                DayDetailView(date: selectedDate, sessions: sessionsForDate(selectedDate)) {
                    sessions = SessionStore.load()
                    plan = PlanStore.load()
                    showDetailView = false
                }
            }
            .sheet(isPresented: $showManualLogSheet) {
                ManualLogSheet(
                    initialDate: manualLogInitialDate,
                    accentColor: themeManager.accentColor.color,
                    weightKg: profile?.weightKg ?? 70,
                    defaultTarget: manualLogDefaultTarget,
                    isPremium: premiumUnlocked,
                    earliestDate: earliestAvailableDate(),
                    onSave: { date, durationMinutes, reps, target in
                        saveManualSession(date: date, durationMinutes: durationMinutes, reps: reps, targetReps: target)
                        showManualLogSheet = false
                    },
                    onCancel: {
                        showManualLogSheet = false
                    }
                )
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
    
    private func clampManualLogDate(_ date: Date) -> Date {
        let now = Date()
        let minOneYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        if !premiumUnlocked {
            return min(max(date, minOneYear), now)
        }
        let earliestAvailable = earliestAvailableDate() ?? minOneYear
        return min(max(date, earliestAvailable), now)
    }
    
    private func saveManualSession(date: Date, durationMinutes: Int, reps: Int, targetReps: Int) {
        guard reps > 0, durationMinutes > 0 else { return }
        let durationSeconds = durationMinutes * 60
        let weightKg = ProfileStore.load()?.weightKg ?? 70
        let calories = Calculations.pushupCalories(reps: reps, durationSeconds: durationSeconds, weightKg: weightKg)
        let dayStart = calendar.startOfDay(for: date)
        let defaultEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date) ?? dayStart.addingTimeInterval(18 * 3600)
        let now = Date()
        let clampedEnd = min(defaultEnd, now)
        let startTime = max(dayStart, clampedEnd.addingTimeInterval(-TimeInterval(durationSeconds)))
        let target = targetReps
        let session = WorkoutSession(
            id: UUID(),
            date: clampedEnd,
            startTime: startTime,
            endTime: clampedEnd,
            reps: reps,
            durationSeconds: durationSeconds,
            mode: .manual,
            caloriesBurned: calories,
            notes: "Logged manually",
            repsTimestamps: [],
            targetRepsAtStart: target,
            modeDisplayOverride: "Manual",
            averageHeartRateBPM: nil,
            maxHeartRateBPM: nil,
            recoveryHeartRateDropBPM: nil
        )
        var all = SessionStore.load()
        all.append(session)
        all.sort { $0.startTime < $1.startTime }
        SessionStore.save(all)
        markPlanDayCompleteIfNeeded(session: session, overrideTarget: targetReps)
        NotificationManager.shared.onWorkoutCompleted()
        NotificationCenter.default.post(name: NSNotification.Name("SessionsUpdated"), object: nil)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        sessions = SessionStore.load()
        plan = PlanStore.load()
        profile = ProfileStore.load()
    }
    
    private func earliestAvailableDate() -> Date? {
        var candidates: [Date] = []
        if let sessionMin = sessions.map({ $0.date }).min() {
            candidates.append(sessionMin)
        }
        if let onboarding = profile?.onboardingDate {
            candidates.append(onboarding)
        }
        if let planStart = plan?.startDate {
            candidates.append(planStart)
        }
        guard !candidates.isEmpty else { return nil }
        return candidates.min()
    }
    
    private func planTarget(for date: Date) -> Int? {
        guard let plan = PlanStore.load() else { return nil }
        let dayStart = calendar.startOfDay(for: date)
        let planStart = calendar.startOfDay(for: plan.startDate)
        guard let diff = calendar.dateComponents([.day], from: planStart, to: dayStart).day, diff >= 0 else {
            return nil
        }
        let dayNumber = diff + 1
        if let planDay = plan.days.first(where: { $0.dayNumber == dayNumber }) {
            return planDay.targetReps
        }
        return plan.targetReps
    }
    
    private func markPlanDayCompleteIfNeeded(session: WorkoutSession, overrideTarget: Int) {
        guard var plan = PlanStore.load() else { return }
        let dayStart = calendar.startOfDay(for: session.date)
        let planStart = calendar.startOfDay(for: plan.startDate)
        guard let diff = calendar.dateComponents([.day], from: planStart, to: dayStart).day else { return }
        let dayNumber = diff + 1
        guard let index = plan.days.firstIndex(where: { $0.dayNumber == dayNumber }) else { return }
        let target = overrideTarget
        guard session.reps >= target else { return }
        plan.days[index].isCompleted = true
        plan.days[index].completedDate = session.endTime
        PlanStore.save(plan)
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
            if dayStart < onboardingStart && daySessions.isEmpty {
                return .none // Only hide if no sessions recorded before onboarding
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

// MARK: - Manual Log Sheet

private struct ManualLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    let minDate: Date
    let maxDate: Date
    let accentColor: Color
    let weightKg: Double
    let defaultTarget: Int?
    let isPremium: Bool
    let earliestDate: Date?
    let oneYearAgo: Date
    let onSave: (Date, Int, Int, Int) -> Void
    let onCancel: () -> Void
    
    @State private var selectedDate: Date
    @State private var durationMinutes: Int = 1
    @State private var reps: Int = 20
    @State private var targetReps: Int
    @State private var showValidationAlert: Bool = false
    @State private var showDateWarning: Bool = false
    
    init(initialDate: Date, accentColor: Color, weightKg: Double, defaultTarget: Int?, isPremium: Bool, earliestDate: Date?, onSave: @escaping (Date, Int, Int, Int) -> Void, onCancel: @escaping () -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let defaultMin = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let premiumMin = earliestDate ?? defaultMin
        let minDate = isPremium ? min(defaultMin, premiumMin) : defaultMin
        let oneYearAgo = defaultMin
        let clampedInitial = max(min(initialDate, now), minDate)
        self._selectedDate = State(initialValue: clampedInitial)
        self.minDate = minDate
        self.maxDate = now
        self.accentColor = accentColor
        self.weightKg = weightKg
        self._targetReps = State(initialValue: max(defaultTarget ?? 20, 1))
        self.onSave = onSave
        self.onCancel = onCancel
        self.defaultTarget = defaultTarget
        self.isPremium = isPremium
        self.earliestDate = earliestDate
        self.oneYearAgo = oneYearAgo
        self._showDateWarning = State(initialValue: isPremium && clampedInitial < oneYearAgo)
    }
    
    private var estimatedCalories: Double {
        Calculations.pushupCalories(reps: reps, durationSeconds: durationMinutes * 60, weightKg: weightKg)
    }
    
    private var canSave: Bool {
        reps > 0 && durationMinutes > 0 && targetReps > 0
    }
    
    private var dateWarningText: String {
        "Workouts earlier than one year stay in iCloud after sync. Recent history remains available on-device."
    }
    
    private func validateDateSelection(_ date: Date) {
        showDateWarning = isPremium && date < oneYearAgo
    }
    
    private func updateSuggestedTarget(for date: Date) {
        guard let plan = PlanStore.load() else { return }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let planStart = calendar.startOfDay(for: plan.startDate)
        guard let diff = calendar.dateComponents([.day], from: planStart, to: dayStart).day else { return }
        let dayNumber = diff + 1
        if let planDay = plan.days.first(where: { $0.dayNumber == dayNumber }) {
            targetReps = max(planDay.targetReps, 1)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Date") {
                    DatePicker("Date", selection: $selectedDate, in: minDate...maxDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(accentColor)
                        .onChange(of: selectedDate) { _, newValue in
                            validateDateSelection(newValue)
                            updateSuggestedTarget(for: newValue)
                        }
                    if showDateWarning {
                        Text(dateWarningText)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                
                Section("Duration") {
                    Stepper(value: $durationMinutes, in: 1...240, step: 1) {
                        Text("\(durationMinutes) minute\(durationMinutes == 1 ? "" : "s")")
                    }
                }
                
                Section("Repetitions") {
                    Stepper(value: $reps, in: 1...2000, step: 1) {
                        Text("\(reps) reps")
                    }
                }
                
                Section("Target Reps") {
                    Stepper(value: $targetReps, in: 1...4000, step: 1) {
                        Text("\(targetReps) target reps")
                    }
                    if let defaultTarget {
                        Text("Plan target for this day: \(defaultTarget) reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Summary") {
                    HStack {
                        Label("Calories", systemImage: "flame.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f kcal", estimatedCalories))
                            .font(.headline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Estimated calories")
                    .accessibilityValue(String(format: "%.0f kilocalories", estimatedCalories))
                    if isPremium {
                        Text("Older workouts will be archived to iCloud after your next backup. Only the latest year stays on-device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard canSave else {
                            showValidationAlert = true
                            return
                        }
                        showDateWarning = false
                        onSave(selectedDate, durationMinutes, reps, targetReps)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Invalid Entry", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please make sure duration and repetitions are greater than zero.")
            }
            .onAppear {
                validateDateSelection(selectedDate)
                updateSuggestedTarget(for: selectedDate)
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
                    
                    let displayMode = session.modeDisplayOverride ?? (session.notes == "Logged manually" ? "Manual" : session.mode.displayName)
                    Text("Mode: \(displayMode)")
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
