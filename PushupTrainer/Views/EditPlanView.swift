import SwiftUI

enum PlanStyle: String, CaseIterable, Identifiable {
    case linear, exponential, stepwise
    var id: String { rawValue }
    var label: String {
        switch self {
        case .linear: return "Linear"
        case .exponential: return "Exponential"
        case .stepwise: return "Stepwise"
        }
    }
}

struct EditPlanView: View {
    @State private var plan: WorkoutPlan? = PlanStore.load()
    @State private var targetRepsText: String = ""
    @State private var currentMaxText: String = ""
    @State private var totalDaysText: String = ""
    @State private var perDayTargets: [String] = []
    @AppStorage("planStyle") private var planStyleRaw: String = PlanStyle.linear.rawValue
    @State private var toastMessage: String? = nil
    @State private var showResetConfirm: Bool = false
    
    private var planStyle: PlanStyle {
        PlanStyle(rawValue: planStyleRaw) ?? .linear
    }
    
    private var planStyleBinding: Binding<PlanStyle> {
        Binding(
            get: { PlanStyle(rawValue: planStyleRaw) ?? .linear },
            set: { planStyleRaw = $0.rawValue }
        )
    }

    var body: some View {
        formContent
            .navigationTitle("Edit Plan")
            .scrollContentBackground(.hidden)
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
                plan = PlanStore.load()
                populateFields() 
            }
            .alert("Reset plan completion?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) { resetPlanCompletion() }
            } message: { Text("This will mark all plan days as incomplete.") }
            .overlay(alignment: .bottom) {
                Group {
                    if let msg = toastMessage {
                        Text(msg)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                            .padding(.bottom, 20)
                            .transition(.opacity)
                    }
                }
            }
    }

    private var formContent: some View {
        Form {
            if let p = plan {
                Section("Plan Settings") {
                    // Invisible anchor for scroll reset
                    Color.clear.frame(height: 0).id("top")
                    
                    HStack { Text("Target Reps"); Spacer(); TextField("", text: $targetRepsText).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Current Max"); Spacer(); TextField("", text: $currentMaxText).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Target Days"); Spacer(); TextField("", text: $totalDaysText).keyboardType(.numberPad).multilineTextAlignment(.trailing) }
                    HStack {
                        Text("Plan Style")
                        Spacer()
                        Picker("", selection: planStyleBinding) {
                            ForEach(PlanStyle.allCases) { style in
                                Text(style.label).tag(style)
                            }
                        }.pickerStyle(.menu)
                    }
                    Button("Regenerate Plan") { regeneratePlan() }
                }

                Section("Daily Targets (tap to edit)") {
                    ForEach(0..<p.days.count, id: \.self) { idx in
                        Stepper(value: bindingForIndex(idx, defaultValue: p.days[idx].targetReps), in: 0...1000) {
                            HStack {
                                Text("Day \(p.days[idx].dayNumber)")
                                Spacer()
                                Text(displayTextForIndex(idx, defaultValue: p.days[idx].targetReps))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("Save Changes") { applyPerDayTargetsAndSave() }
                }

                Section("Actions") {
                    Button(role: .destructive, action: {
                        showResetConfirm = true
                    }) {
                        Label("Reset Plan Completion", systemImage: "arrow.uturn.backward")
                    }
                }
            } else {
                Text("No plan found. Create one from Settings.")
                    .foregroundStyle(.secondary)
            }
        }
        .defaultScrollAnchor(.top)
    }

    private func resetPlanCompletion() {
        guard var p = PlanStore.load() else { return }
        for i in p.days.indices {
            p.days[i].isCompleted = false
            p.days[i].completedDate = nil
        }
        PlanStore.save(p)
        plan = p
        showToast(message: "Plan reset")
        NotificationCenter.default.post(name: NSNotification.Name("SessionsUpdated"), object: nil)
    }
    private func populateFields() {
        if let p = plan {
            targetRepsText = String(p.targetReps)
            currentMaxText = String(p.currentMax)
            totalDaysText = String(p.totalDays)
            perDayTargets = p.days.map { String($0.targetReps) }
        }
    }

    private func regeneratePlan() {
        guard let tgt = Int(targetRepsText), let cur = Int(currentMaxText), let days = Int(totalDaysText) else { return }
        
        // Preserve existing plan metadata if available
        let oldPlan = plan
        let preservedStartDate = oldPlan?.startDate ?? Date()
        let preservedPlanId = oldPlan?.id ?? UUID()
        
        // Create a map of old day numbers to completion status
        var completionMap: [Int: (isCompleted: Bool, completedDate: Date?)] = [:]
        if let old = oldPlan {
            for day in old.days {
                completionMap[day.dayNumber] = (day.isCompleted, day.completedDate)
            }
        }
        
        var daysArray: [PlanDay] = []
        let delta = max(0, tgt - cur)
        
        switch planStyle {
        case .linear:
            for i in 1...max(1, days) {
                let fraction = Double(i) / Double(max(1, days))
                let reps = cur + Int(round(Double(delta) * fraction))
                let preserved = completionMap[i] ?? (isCompleted: false, completedDate: nil)
                daysArray.append(PlanDay(id: UUID(), dayNumber: i, targetReps: min(max(cur, reps), tgt), isCompleted: preserved.isCompleted, completedDate: preserved.completedDate))
            }
        case .exponential:
            for i in 1...max(1, days) {
                let t = Double(i) / Double(max(1, days))
                let eased = pow(t, 1.5) // Slightly slower ramp than t^2
                let reps = cur + Int(round(Double(delta) * eased))
                let preserved = completionMap[i] ?? (isCompleted: false, completedDate: nil)
                daysArray.append(PlanDay(id: UUID(), dayNumber: i, targetReps: min(max(cur, reps), tgt), isCompleted: preserved.isCompleted, completedDate: preserved.completedDate))
            }
        case .stepwise:
            let steps = max(1, min(days / 5, 10))
            let repsPerStep = Double(delta) / Double(steps)
            for i in 1...max(1, days) {
                let stepIndex = Int(floor(Double(i) * Double(steps) / Double(max(1, days))))
                let reps = cur + Int(round(repsPerStep * Double(stepIndex)))
                let preserved = completionMap[i] ?? (isCompleted: false, completedDate: nil)
                daysArray.append(PlanDay(id: UUID(), dayNumber: i, targetReps: min(max(cur, reps), tgt), isCompleted: preserved.isCompleted, completedDate: preserved.completedDate))
            }
        }
        
        // Ensure the last day exactly matches the target reps
        if let last = daysArray.indices.last { daysArray[last].targetReps = tgt }
        
        let newPlan = WorkoutPlan(id: preservedPlanId, startDate: preservedStartDate, totalDays: days, days: daysArray, targetReps: tgt, currentMax: cur)
        plan = newPlan
        perDayTargets = newPlan.days.map { String($0.targetReps) }
        savePlan()
        showToast(message: "Plan updated")
    }

    private func applyPerDayTargetsAndSave() {
        guard var p = plan else { return }
        for i in p.days.indices {
            if i < perDayTargets.count, let v = Int(perDayTargets[i]) {
                p.days[i].targetReps = v
            }
        }
        plan = p
        savePlan()
    }

    private func savePlan() {
        if let p = plan {
            PlanStore.save(p)
            NotificationCenter.default.post(name: NSNotification.Name("SessionsUpdated"), object: nil)
        }
    }

    private func showToast(message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { toastMessage = nil }
    }

    private func bindingForIndex(_ idx: Int, defaultValue: Int) -> Binding<Int> {
        Binding<Int>(
            get: {
                if idx < perDayTargets.count, let v = Int(perDayTargets[idx]) { return v }
                return defaultValue
            },
            set: { newVal in
                if perDayTargets.count <= idx {
                    perDayTargets = Array(perDayTargets + Array(repeating: "", count: idx - perDayTargets.count + 1))
                }
                perDayTargets[idx] = String(newVal)
            }
        )
    }

    private func displayTextForIndex(_ idx: Int, defaultValue: Int) -> String {
        if idx < perDayTargets.count, let v = Int(perDayTargets[idx]) { return "\(v) reps" }
        return "\(defaultValue) reps"
    }
}
